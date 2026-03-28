import SwiftUI

// MARK: - NotesTheme
// Adaptive palette — automatically correct in light and dark mode.
// All Color values use UIColor dynamic providers so they respond to
// system appearance changes without any @Environment wiring in views.

enum NotesTheme {

    // MARK: Background (flat fallback; use notesBackground() for the gradient)
    static let bg = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.039, green: 0.102, blue: 0.039, alpha: 1)  // #0A1A0A
            : UIColor(red: 0.941, green: 0.980, blue: 0.941, alpha: 1)  // #F0FAF0
    })

    // MARK: Card fills (prefer notesCard() / notesRowSurface() modifiers)
    static let card = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(white: 1, alpha: 0.55)
    })
    static let cardStrong = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.12)
            : UIColor(white: 1, alpha: 0.70)
    })
    // Stroke used by notesCard() / notesRowSurface()
    static let cardStroke = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.14)
            : UIColor(white: 1, alpha: 0.90)
    })

    // MARK: Divider
    static let divider = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(white: 0, alpha: 0.06)
    })

    // MARK: Text
    static let textPrimary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? .white
            : UIColor(red: 0.102, green: 0.180, blue: 0.102, alpha: 1)  // #1A2E1A
    })
    static let textSecondary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.68)
            : UIColor(white: 0, alpha: 0.55)
    })
    static let textTertiary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.48)
            : UIColor(white: 0, alpha: 0.35)
    })

    // MARK: Accent (matches the adaptive AccentColor asset above)
    static let accent = Color.accentColor
    static let accentSoft = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.290, green: 0.867, blue: 0.502, alpha: 0.18)
            : UIColor(red: 0.086, green: 0.392, blue: 0.204, alpha: 0.12)
    })

    // MARK: Geometry
    static let radius: CGFloat = 22
    static let rowRadius: CGFloat = 18
}

// MARK: - Adaptive background gradient

private struct GSPBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: "0A0A0A"), Color(hex: "0D1A0D"), Color(hex: "0A120A")]
                : [Color(hex: "E8F5E9"), Color(hex: "F0FAF0"), Color(hex: "E0F2F1")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Surface modifiers

extension View {
    /// Full-screen adaptive gradient background. Use instead of .background(NotesTheme.bg).
    func notesBackground() -> some View {
        self.background(GSPBackgroundView())
    }

    /// Glass card surface with shadow + stroke. Use for content blocks and list containers.
    func notesCard(cornerRadius: CGFloat = NotesTheme.radius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(NotesTheme.cardStroke, lineWidth: 1)
            )
    }

    /// Convenience alias for row-radius glass card.
    func notesRowSurface() -> some View {
        notesCard(cornerRadius: NotesTheme.rowRadius)
    }
}

// MARK: - Screen title

struct NotesScreenTitle: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundStyle(NotesTheme.textPrimary)
                .gspFont(.screenTitle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .foregroundStyle(NotesTheme.textSecondary)
                    .gspFont(.screenSubtitle)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }
}

// MARK: - Chevron Row (tap target)

struct NotesChevronRow: View {
    let title: String
    let subtitle: String?
    var trailing: String? = nil
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .foregroundStyle(NotesTheme.textPrimary)
                        .gspFont(.rowTitle)
                        .lineLimit(2)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .foregroundStyle(NotesTheme.textSecondary)
                            .gspFont(.rowSubtitle)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                if let trailing, !trailing.isEmpty {
                    Text(trailing)
                        .foregroundStyle(NotesTheme.textTertiary)
                        .gspFont(.rowTrailing)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(NotesTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .notesRowSurface()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon Pill

struct NotesIconPillButton: View {
    let systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundStyle(NotesTheme.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .background(baseBackground)
                .overlay(baseRim)
                .overlay(directionGlint)
                .overlay(innerShadow)
                .overlay(sheenPatch)
        }
        .buttonStyle(.plain)
    }

    private var baseBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(Circle().fill(Color.white.opacity(0.06)))
            .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 6)
    }

    private var baseRim: some View {
        Circle()
            .strokeBorder(NotesTheme.cardStroke, lineWidth: 1)
    }

    private var directionGlint: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.62),
                        Color.white.opacity(0.14),
                        Color.white.opacity(0.10)
                    ],
                    center: .center,
                    angle: .degrees(-55)
                ),
                lineWidth: 1
            )
            .blendMode(.screen)
            .opacity(0.60)
    }

    private var innerShadow: some View {
        Circle()
            .stroke(Color.black.opacity(0.38), lineWidth: 1)
            .blur(radius: 1.2)
            .mask(
                Circle().fill(
                    LinearGradient(
                        colors: [Color.black, Color.clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            )
            .blendMode(.multiply)
            .opacity(0.70)
            .allowsHitTesting(false)
    }

    private var sheenPatch: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.00)],
                    center: .topTrailing,
                    startRadius: 1,
                    endRadius: 18
                )
            )
            .blendMode(.screen)
            .opacity(0.75)
            .allowsHitTesting(false)
    }
}

// MARK: - Color(hex:) helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
