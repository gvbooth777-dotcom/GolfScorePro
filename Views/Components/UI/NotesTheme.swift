//
//  NotesTheme.swift
//  GolfScorePro
//
//  Refactor: 2026-02-16 14:xx PT
//
//  What you should see now:
//  - NotesTheme remains palette + surfaces (dark-only).
//  - Typography is delegated to GSPDesign / GSPTextStyle (single source of truth).
//  - Fixes compile errors caused by duplicate GSPTextStyle declarations.
//

import SwiftUI

enum NotesTheme {
    // Dark-only palette
    static let bg = Color.black
    static let card = Color.white.opacity(0.08)
    static let cardStrong = Color.white.opacity(0.12)
    static let divider = Color.white.opacity(0.10)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.48)

    // Accent
    static let accent = Color.accentColor

    static let radius: CGFloat = 22
    static let rowRadius: CGFloat = 18
}

// MARK: - Surfaces

extension View {
    func notesBackground() -> some View {
        self.background(NotesTheme.bg.ignoresSafeArea())
    }

    func notesCard(cornerRadius: CGFloat = NotesTheme.radius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(NotesTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(NotesTheme.divider, lineWidth: 1)
            )
    }

    func notesRowSurface() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous)
                    .fill(NotesTheme.cardStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous)
                    .strokeBorder(NotesTheme.divider, lineWidth: 1)
            )
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
                .foregroundStyle(Color.white.opacity(0.92))
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
            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
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
                    colors: [
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.00)
                    ],
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
