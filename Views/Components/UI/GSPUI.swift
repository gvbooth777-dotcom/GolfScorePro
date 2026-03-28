//
//  GSPUI.swift
//  GolfScorePro
//
//  Created by Greg Booth on 2/25/26.
//  Refactor: 2026-02-25  (LiveRoundView UI → Global Design System)
//
//  WHAT YOU SHOULD SEE NOW
//  - A single, canonical “knobs + parts” file that matches LiveRoundView.
//  - No guessing: spacing, radii, font, opacity, sizes live here.
//  - Reusable building blocks that immediately standardize:
//      • list blocks + dividers (LiveRound rows feel)
//      • primary/secondary pills (LiveRound CTAs)
//      • top-bar + hole-nav icon pills (LiveRound circular pills)
//      • avatar circle (LiveRound avatar)
//      • toast HUD (LiveRound toast)
//
//  NOTES
//  - Swift cannot use a nested type named `Type` (conflicts with `foo.Type`), so we use `Typography`.
//  - Keep this file restrained. If a view needs a new knob, add it here and wire it everywhere.
//

import SwiftUI

// MARK: - GolfScorePro UI Knobs (Source of truth: LiveRoundView)
//
// Single global knobs file (no guessing).
// This file holds THE ONLY spacing/font/opacity/radius constants allowed.
//

enum GSPUI {

    // MARK: Spacing

    enum Spacing {
        // Page / layout
        static let pageTop: CGFloat = 6
        static let sectionVStack: CGFloat = 16

        // Insets
        static let insetX: CGFloat = 18
        static let insetTopBarTop: CGFloat = 6
        static let insetTopBarBottom: CGFloat = 10

        // Lists / rows
        static let listTop: CGFloat = 2
        static let rowVPad: CGFloat = 16          // main standings rows
        static let rowHStack: CGFloat = 14
        static let dividerLeading: CGFloat = 78

        // Cards / status strips
        static let cardPad: CGFloat = 16          // interior padding for game-summary cards
        static let stripVPad: CGFloat = 12        // vertical padding for status strips
        static let stripLineSpacing: CGFloat = 6  // spacing between lines inside a strip
        static let holeRowVPad: CGFloat = 12      // compact player rows in hole detail

        // Bottom bar
        static let bottomBarBottom: CGFloat = 12
        static let bottomBarPadBottom: CGFloat = 22

        // Toast
        static let toastBottom: CGFloat = 96
        static let toastContainerHeight: CGFloat = 120
        static let toastSideInset: CGFloat = 36
    }

    // MARK: Sizes

    enum Size {
        // Avatar + icon pills
        static let avatar: CGFloat = 56
        static let iconPill: CGFloat = 58

        // Typography sizes (numbers)
        static let scoreFont: CGFloat = 38

        // Pill heights
        static let postHeight: CGFloat = 72
        static let toastHeight: CGFloat = 64

        // Toast sizing
        static let toastMaxWidth: CGFloat = 520

        // Icons
        static let chevron: CGFloat = 16
        static let topBarIcon: CGFloat = 18
    }

    // MARK: Radius

    enum Radius {
        // LiveRoundView
        static let pillPrimary: CGFloat = 30
        static let pillSecondary: CGFloat = 22

        // Cards / containers (Home library, sheets, etc.)
        // NOTE: this was the missing token causing: "GSPUI.Radius has no member 'card'"
        static let card: CGFloat = 26
    }

    // MARK: Opacity

    enum Opacity {
        static let divider: Double = 0.10

        static let disabled: Double = 0.35
        static let disabledSoft: Double = 0.60

        static let chevron: Double = 0.55
        static let whiteStroke: Double = 0.22
        static let whiteText: Double = 0.92
    }

    // MARK: Typography (formerly "Type" → renamed because Swift forbids nested `Type`)

    enum Typography {
        static let title3Semibold = Font.system(.title3, design: .default).weight(.semibold)
        static let bodyRegular = Font.system(.body, design: .default).weight(.regular)
        static let headline = Font.system(.headline, design: .default)

        static let score = Font.system(size: Size.scoreFont, weight: .semibold, design: .default)
        static let post = Font.system(size: 28, weight: .semibold, design: .default)
        static let primaryCTA = Font.system(size: 24, weight: .semibold, design: .default)
    }
}

// MARK: - Reusable building blocks (Source of truth: LiveRoundView)

/// Standard list block container (rows + dividers) used for Library lists, Players lists, Courses lists, etc.
/// Uses LiveRoundView paddings.
struct GSPListBlock<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, GSPUI.Spacing.insetX)
            .padding(.top, GSPUI.Spacing.listTop)
    }
}

/// Standard divider used between rows (matches LiveRoundView).
struct GSPDivider: View {
    var leading: CGFloat = GSPUI.Spacing.dividerLeading

    var body: some View {
        Divider()
            .overlay(Color.white.opacity(GSPUI.Opacity.divider))
            .padding(.leading, leading)
    }
}

// MARK: - Pills

/// Primary CTA pill (Post / Finish Round / Add Players) — matches LiveRoundView.
struct GSPPrimaryPill: View {
    let title: String
    let accent: Color

    var height: CGFloat = GSPUI.Size.postHeight
    var font: Font = GSPUI.Typography.post
    var shadowEnabled: Bool = true

    var body: some View {
        Text(title)
            .foregroundStyle(.black.opacity(0.92))
            .font(font)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: GSPUI.Radius.pillPrimary, style: .continuous)
                    .fill(accent)
                    .shadow(
                        color: Color.black.opacity(shadowEnabled ? 0.28 : 0.0),
                        radius: shadowEnabled ? 14 : 0,
                        x: 0,
                        y: shadowEnabled ? 12 : 0
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: GSPUI.Radius.pillPrimary, style: .continuous))
            .accessibilityAddTraits(.isButton)
    }
}

/// Secondary pill used for "Not Now" / "Keep Scoring" style actions.
struct GSPSecondaryPill: View {
    let title: String

    var height: CGFloat = 60
    var font: Font = GSPUI.Typography.headline

    var body: some View {
        Text(title)
            .foregroundStyle(NotesTheme.textPrimary)
            .font(font)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: GSPUI.Radius.pillSecondary, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .contentShape(RoundedRectangle(cornerRadius: GSPUI.Radius.pillSecondary, style: .continuous))
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Icon Pill Buttons (Top bars + Hole nav)

/// Notes-style icon pill button — wrapper so all views match LiveRoundView.
/// Use this everywhere instead of ad-hoc icon buttons.
struct GSPIconPillButton: View {
    let systemName: String

    var size: CGFloat = GSPUI.Size.iconPill
    var iconSize: CGFloat = GSPUI.Size.topBarIcon
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold, design: .default))
                .foregroundStyle(NotesTheme.textPrimary)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.25)
        .accessibilityLabel(systemName)
    }
}

// MARK: - Avatar Circle

/// Avatar circle used in LiveRoundView. Can also double as a restrained “icon” language.
struct GSPAvatarCircle: View {
    let initials: String

    var size: CGFloat = GSPUI.Size.avatar
    var fill: Color = Color.white.opacity(0.14)

    var body: some View {
        Text(initials.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "?" : initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .default))
            .foregroundStyle(Color.white.opacity(GSPUI.Opacity.whiteText))
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(fill)
                    .overlay(Circle().stroke(Color.white.opacity(GSPUI.Opacity.whiteStroke), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 8)
            )
            .accessibilityLabel("Avatar \(initials)")
    }
}

// MARK: - Toast HUD (matches LiveRoundView)

struct GSPToastHUD: View {
    let text: String
    let accent: Color
    let width: CGFloat

    var body: some View {
        Text(text)
            .foregroundStyle(.black.opacity(0.92))
            .font(GSPUI.Typography.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: width, height: GSPUI.Size.toastHeight)
            .background(
                RoundedRectangle(cornerRadius: GSPUI.Radius.pillPrimary, style: .continuous)
                    .fill(accent)
                    .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 14)
            )
            .accessibilityLabel(text)
    }
}
