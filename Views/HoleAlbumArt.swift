//
//  HoleAlbumArt.swift
//  GolfScorePro
//
//  Created by Greg Booth on 1/18/26.
//
import SwiftUI

/// A deterministic, Apple Music–style geometric "album cover" for a given hole.
/// - Fast: pure SwiftUI vector drawing
/// - Deterministic: seeded by (courseName + holeNumber)
/// - Cache-friendly: view is stable for same inputs
struct HoleAlbumArt: View {
    let courseName: String
    let holeNumber: Int
    var size: CGFloat = 72

    var body: some View {
        let seed = HoleArtSeed(courseName: courseName, holeNumber: holeNumber)

        ZStack {
            // Base
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.55))

            // Soft "vinyl" glow
            RadialGradient(
                gradient: Gradient(colors: [
                    seed.palette.glow.opacity(0.55),
                    Color.black.opacity(0.0)
                ]),
                center: .topLeading,
                startRadius: 4,
                endRadius: size * 0.85
            )
            .blendMode(.screen)

            // Geometric layers
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // Background bands
                BandLayer(seed: seed, width: w, height: h)
                    .opacity(0.95)

                // Primary shape
                PrimaryShapeLayer(seed: seed, width: w, height: h)
                    .opacity(0.95)

                // Accent micro-shapes
                AccentGlyphs(seed: seed, width: w, height: h)
                    .opacity(0.9)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Subtle glass stroke
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                .allowsHitTesting(false)

            // Optional "Hole" mark
            VStack {
                Spacer()
                HStack {
                    Text("HOLE \(holeNumber)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.90))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.35))
                                .overlay(
                                    Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        )
                    Spacer()
                }
                .padding(10)
            }
            .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.75), radius: 18, x: 0, y: 10)
        .drawingGroup(opaque: false, colorMode: .linear) // smooth + fast
        .accessibilityLabel("Hole \(holeNumber) album art")
    }
}

// MARK: - Seed + Palette

struct HoleArtSeed: Hashable {
    let courseName: String
    let holeNumber: Int
    let rng: SeededRNG
    let palette: HolePalette

    init(courseName: String, holeNumber: Int) {
        self.courseName = courseName
        self.holeNumber = holeNumber
        let s = HoleArtSeed.hash64("\(courseName)|\(holeNumber)")
        self.rng = SeededRNG(seed: s)
        self.palette = HolePalette.make(seed: s)
    }

    static func hash64(_ string: String) -> UInt64 {
        // FNV-1a 64-bit
        var hash: UInt64 = 1469598103934665603
        let prime: UInt64 = 1099511628211
        for b in string.utf8 {
            hash ^= UInt64(b)
            hash &*= prime
        }
        return hash
    }
}

struct HolePalette: Hashable {
    let a: Color
    let b: Color
    let c: Color
    let accent: Color
    let glow: Color

    static func make(seed: UInt64) -> HolePalette {
        // Apple Music-ish: premium neons but controlled.
        // Keep your "pink-red accent" dominant.
        let base = Color.black
        let pink = Color(red: 1.0, green: 0.18, blue: 0.42)     // pink-red
        let magenta = Color(red: 0.78, green: 0.22, blue: 1.0)
        let cyan = Color(red: 0.20, green: 0.86, blue: 1.0)
        let lime = Color(red: 0.54, green: 1.0, blue: 0.38)

        // Light deterministic rotation between a few complements
        let choice = Int(seed % 4)
        switch choice {
        case 0: return .init(a: pink, b: magenta, c: cyan, accent: pink, glow: magenta)
        case 1: return .init(a: pink, b: cyan, c: magenta, accent: pink, glow: cyan)
        case 2: return .init(a: pink, b: magenta, c: lime, accent: pink, glow: lime)
        default:return .init(a: pink, b: cyan, c: lime, accent: pink, glow: magenta)
        }
    }
}

// MARK: - Deterministic RNG

struct SeededRNG: Hashable {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func nextUInt64() -> UInt64 {
        // SplitMix64
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double {
        let x = nextUInt64() >> 11
        return Double(x) / Double(1 << 53)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * nextDouble()
    }

    mutating func nextInt(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }
}

// MARK: - Layers

private struct BandLayer: View {
    let seed: HoleArtSeed
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        var rng = seed.rng

        let bandCount = 3 + rng.nextInt(3) // 3...5
        let angle = Angle(degrees: rng.next(in: -22...22))
        let colors: [Color] = [seed.palette.a, seed.palette.b, seed.palette.c]

        return ZStack {
            ForEach(0..<bandCount, id: \.self) { i in
                let t = CGFloat(i) / CGFloat(max(bandCount - 1, 1))
                let y = height * (0.15 + 0.7 * t)
                let bandH = height * CGFloat(rng.next(in: 0.10...0.18))

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                colors[i % colors.count].opacity(0.95),
                                Color.black.opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width * 1.25, height: bandH)
                    .rotationEffect(angle)
                    .offset(x: -width * 0.10, y: y - height * 0.5)
                    .blendMode(.screen)
                    .blur(radius: 0.4)
            }
        }
    }
}

private struct PrimaryShapeLayer: View {
    let seed: HoleArtSeed
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        var rng = seed.rng

        let shapeType = rng.nextInt(3) // 0 circle, 1 rounded rect, 2 arc
        let x = CGFloat(rng.next(in: 0.18...0.82)) * width
        let y = CGFloat(rng.next(in: 0.18...0.82)) * height
        let s = CGFloat(rng.next(in: 0.42...0.78)) * min(width, height)

        let grad = RadialGradient(
            gradient: Gradient(colors: [
                seed.palette.accent.opacity(0.95),
                seed.palette.b.opacity(0.20),
                Color.black.opacity(0.0)
            ]),
            center: UnitPoint(x: x / width, y: y / height),
            startRadius: 1,
            endRadius: s * 0.9
        )

        return ZStack {
            switch shapeType {
            case 0:
                Circle()
                    .fill(grad)
                    .frame(width: s, height: s)
                    .position(x: x, y: y)
                    .blendMode(.screen)

            case 1:
                RoundedRectangle(cornerRadius: s * 0.22, style: .continuous)
                    .fill(grad)
                    .frame(width: s * 1.05, height: s * 0.78)
                    .rotationEffect(.degrees(rng.next(in: -18...18)))
                    .position(x: x, y: y)
                    .blendMode(.screen)

            default:
                ArcRing()
                    .stroke(
                        LinearGradient(
                            colors: [seed.palette.accent.opacity(0.95), seed.palette.c.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: s * 0.07, lineCap: .round)
                    )
                    .frame(width: s, height: s)
                    .rotationEffect(.degrees(rng.next(in: 0...360)))
                    .position(x: x, y: y)
                    .blendMode(.screen)
                    .blur(radius: 0.2)
            }
        }
    }
}

private struct AccentGlyphs: View {
    let seed: HoleArtSeed
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        var rng = seed.rng
        let count = 6 + rng.nextInt(7) // 6...12

        return ZStack {
            ForEach(0..<count, id: \.self) { _ in
                let x = CGFloat(rng.next(in: 0.08...0.92)) * width
                let y = CGFloat(rng.next(in: 0.10...0.90)) * height
                let w = CGFloat(rng.next(in: 6...14))
                let h = CGFloat(rng.next(in: 2...6))
                let rot = Angle(degrees: rng.next(in: 0...360))
                let color = [seed.palette.a, seed.palette.b, seed.palette.c][rng.nextInt(3)]

                Capsule()
                    .fill(color.opacity(0.75))
                    .frame(width: w, height: h)
                    .rotationEffect(rot)
                    .position(x: x, y: y)
                    .blendMode(.screen)
            }
        }
    }
}

private struct ArcRing: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        p.addArc(center: center, radius: r, startAngle: .degrees(22), endAngle: .degrees(302), clockwise: false)
        return p
    }
}

