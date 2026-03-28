# GolfScorePro UI Redesign — Fairway Light Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign every screen to the "Fairway Light" aesthetic — iOS 26 adaptive light/dark, `.ultraThinMaterial` glass surfaces, golf-native green palette, Hole Hero scoring screen, leading SF Symbol icons in list rows, and polished empty states.

**Architecture:** Update `NotesTheme` in place to adaptive `UIColor`-based tokens (no rename churn). Replace flat `Color.black` / `Color.white.opacity()` surfaces with `.ultraThinMaterial` + glass stroke modifiers. View files need only minor targeted edits because the design system cascades automatically.

**Tech Stack:** SwiftUI, SwiftData, iOS 26+, `.ultraThinMaterial`

**Build command (use after every task):**
```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

## Phase 1 — Design System (Tasks 1–4, sequential)

Tasks 5–12 depend on Phase 1 being complete. Run Tasks 5–12 in parallel after Task 4.

---

### Task 1: Adaptive AccentColor asset + NotesTheme palette

**Files:**
- Modify: `GolfScorePro/Assets.xcassets/AccentColor.colorset/Contents.json`
- Modify: `Views/Components/UI/NotesTheme.swift`

- [ ] **Step 1: Update AccentColor to light/dark adaptive**

Replace the entire contents of `GolfScorePro/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.204",
          "green" : "0.392",
          "red" : "0.086"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.502",
          "green" : "0.867",
          "red" : "0.290"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 2: Replace NotesTheme.swift with adaptive palette**

Replace the entire contents of `Views/Components/UI/NotesTheme.swift`:

```swift
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
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add GolfScorePro/Assets.xcassets/AccentColor.colorset/Contents.json \
        Views/Components/UI/NotesTheme.swift
git commit -m "feat: adaptive Fairway Light palette + glass surface modifiers

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Update GSPDesign typography to Dynamic Type

**Files:**
- Modify: `Views/Components/UI/GSPDesign.swift`

- [ ] **Step 1: Replace hardcoded sizes with Dynamic Type scales**

Replace the `font(_:)` method inside `GSPDesign`:

```swift
static func font(_ style: GSPTextStyle) -> Font {
    switch style {
    case .screenTitle:    return .largeTitle.bold()
    case .screenSubtitle: return .subheadline
    case .sectionTitle:   return .caption.weight(.semibold)
    case .rowTitle:       return .body.weight(.semibold)
    case .rowSubtitle:    return .subheadline
    case .rowTrailing:    return .subheadline.weight(.semibold)
    case .pillTitle:      return .title2.weight(.semibold)
    case .pillSubtitle:   return .subheadline
    case .sheetTitle:     return .title3.weight(.semibold)
    case .sheetAction:    return .headline
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Views/Components/UI/GSPDesign.swift
git commit -m "feat: Dynamic Type typography scales

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Update GSPUI shared components

**Files:**
- Modify: `Views/Components/UI/GSPUI.swift`

- [ ] **Step 1: Update GSPPrimaryPill to support glass (posted) state**

Replace the `GSPPrimaryPill` struct body:

```swift
struct GSPPrimaryPill: View {
    let title: String
    let accent: Color

    var height: CGFloat = GSPUI.Size.postHeight
    var font: Font = GSPUI.Typography.post
    var shadowEnabled: Bool = true
    var isGlass: Bool = false   // true when action is already complete (posted state)

    var body: some View {
        Text(title)
            .foregroundStyle(isGlass ? NotesTheme.accent : Color(UIColor { t in
                t.userInterfaceStyle == .dark ? .black : .white
            }))
            .font(font)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(pillBackground)
            .contentShape(RoundedRectangle(cornerRadius: GSPUI.Radius.pillPrimary, style: .continuous))
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var pillBackground: some View {
        if isGlass {
            RoundedRectangle(cornerRadius: GSPUI.Radius.pillPrimary, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: GSPUI.Radius.pillPrimary, style: .continuous)
                        .strokeBorder(NotesTheme.cardStroke, lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: GSPUI.Radius.pillPrimary, style: .continuous)
                .fill(accent)
                .shadow(
                    color: Color.black.opacity(shadowEnabled ? 0.28 : 0.0),
                    radius: shadowEnabled ? 14 : 0,
                    x: 0, y: shadowEnabled ? 12 : 0
                )
        }
    }
}
```

- [ ] **Step 2: Update GSPSecondaryPill to use material**

Replace the `GSPSecondaryPill` body:

```swift
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
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: GSPUI.Radius.pillSecondary, style: .continuous)
                            .strokeBorder(NotesTheme.cardStroke, lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: GSPUI.Radius.pillSecondary, style: .continuous))
            .accessibilityAddTraits(.isButton)
    }
}
```

- [ ] **Step 3: Update GSPToastHUD foreground**

Replace the `GSPToastHUD` body's `.foregroundStyle` line:

```swift
// Change:
.foregroundStyle(.black.opacity(0.92))
// To:
.foregroundStyle(Color(UIColor { t in
    t.userInterfaceStyle == .dark ? .black : .white
}))
```

- [ ] **Step 4: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Views/Components/UI/GSPUI.swift
git commit -m "feat: glass variant for GSPPrimaryPill, material GSPSecondaryPill

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Add leading icon to NotesChevronRowLabel

**Files:**
- Modify: `Views/Components/UI/NotesChevronRowLabel.swift`

- [ ] **Step 1: Add optional icon parameter and icon view**

Replace the entire file:

```swift
import SwiftUI

/// Label-only version of NotesChevronRow.
/// Use inside NavigationLink labels where you don't want an action closure.
struct NotesChevronRowLabel: View {
    let title: String
    let subtitle: String
    let trailing: String
    var icon: String? = nil   // SF Symbol name; shows accentSoft circle when set

    var body: some View {
        HStack(spacing: 14) {

            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NotesTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(NotesTheme.accentSoft))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .gspFont(.rowTitle)
                    .foregroundStyle(NotesTheme.textPrimary)
                    .lineLimit(1)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .gspFont(.rowSubtitle)
                        .foregroundStyle(NotesTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if !trailing.isEmpty {
                Text(trailing)
                    .gspFont(.rowTrailing)
                    .foregroundStyle(NotesTheme.textTertiary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(NotesTheme.textTertiary)
        }
        .padding(16)
        .notesRowSurface()
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Views/Components/UI/NotesChevronRowLabel.swift
git commit -m "feat: optional leading icon in NotesChevronRowLabel

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Phase 2 — Views (Tasks 5–12, run in parallel after Task 4)

---

### Task 5: Update HomeView

**Files:**
- Modify: `Views/Home/HomeView.swift`

- [ ] **Step 1: Update Library rows with SF Symbol icons**

In `HomeView.body`, find the three `NavigationLink` blocks inside the Library `VStack`. Update each `NotesChevronRowLabel` call to pass an `icon`:

```swift
// Rounds row — change to:
NotesChevronRowLabel(
    title: "Rounds",
    subtitle: "View • Delete",
    trailing: "",
    icon: "flag.fill"
)

// Courses row — change to:
NotesChevronRowLabel(
    title: "Courses",
    subtitle: "Select • Add • Edit",
    trailing: "",
    icon: "mappin.circle.fill"
)

// Players row — change to:
NotesChevronRowLabel(
    title: "Players",
    subtitle: "Optional • For faster setup",
    trailing: "",
    icon: "person.fill"
)
```

- [ ] **Step 2: Update heroActionPill to glass card style**

Replace the `heroActionPill` function:

```swift
private func heroActionPill(title: String, subtitle: String) -> some View {
    HStack(spacing: GSPUI.Spacing.rowHStack) {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .semibold, design: .default))
                .foregroundStyle(NotesTheme.textPrimary)
                .lineLimit(1)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(NotesTheme.textSecondary)
                .lineLimit(1)
        }

        Spacer(minLength: 12)

        Image(systemName: "arrow.right.circle.fill")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(NotesTheme.accent)
    }
    .padding(.horizontal, 22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: 96)
    .background(
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(NotesTheme.accentSoft)
            )
            .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 6)
    )
    .overlay(
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .strokeBorder(NotesTheme.cardStroke, lineWidth: 1)
    )
    .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
}
```

- [ ] **Step 3: Remove the Divider + cardStrong library block, let rows use notesRowSurface()**

The Library block currently wraps rows in a single card with explicit `Divider()` lines. Replace the entire Library `VStack` content (`VStack(spacing: 0) { ... }` inside the Library section) with spaced individual rows:

```swift
VStack(spacing: 10) {
    NavigationLink(value: Route.rounds) {
        NotesChevronRowLabel(
            title: "Rounds",
            subtitle: "View • Delete",
            trailing: "",
            icon: "flag.fill"
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)

    NavigationLink(value: Route.courses) {
        NotesChevronRowLabel(
            title: "Courses",
            subtitle: "Select • Add • Edit",
            trailing: "",
            icon: "mappin.circle.fill"
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)

    NavigationLink(value: Route.players) {
        NotesChevronRowLabel(
            title: "Players",
            subtitle: "Optional • For faster setup",
            trailing: "",
            icon: "person.fill"
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}
.padding(.horizontal, GSPUI.Spacing.insetX)
```

- [ ] **Step 4: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Views/Home/HomeView.swift
git commit -m "feat: HomeView Fairway Light — glass CTA pill, icon library rows

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 6: Implement Hole Hero + glass player cards in LiveRoundView

**Files:**
- Modify: `Views/LiveRound/LiveRoundView.swift`

- [ ] **Step 1: Add holeHero computed var**

Add this below the `topBar` computed var (after the closing brace of `topBar`):

```swift
// MARK: - Hole Hero Header

private var holeHero: some View {
    HStack(alignment: .bottom, spacing: 0) {
        VStack(alignment: .leading, spacing: 2) {
            Text("HOLE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NotesTheme.textTertiary)
                .kerning(1)
            Text("\(round.currentHole)")
                .font(.system(size: 72, weight: .black, design: .default))
                .foregroundStyle(NotesTheme.textPrimary)
                .monospacedDigit()
        }

        Spacer()

        HStack(spacing: 8) {
            holeChip(value: "\(currentPar)", label: "Par")
            holeChip(value: "\(currentSI)", label: "SI")
        }
        .padding(.bottom, 8)
    }
    .padding(.horizontal, GSPUI.Spacing.insetX)
    .padding(.top, 4)
}

private func holeChip(value: String, label: String) -> some View {
    VStack(spacing: 2) {
        Text(value)
            .font(.headline.weight(.bold))
            .foregroundStyle(NotesTheme.textPrimary)
            .monospacedDigit()
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(NotesTheme.textTertiary)
    }
    .frame(width: 48, height: 48)
    .notesCard(cornerRadius: 12)
}

private var holeCourseLabel: some View {
    Text(round.courseName)
        .font(.caption)
        .foregroundStyle(NotesTheme.textTertiary)
        .padding(.horizontal, GSPUI.Spacing.insetX)
        .padding(.bottom, 2)
}
```

- [ ] **Step 2: Replace NotesScreenTitle in `content` with holeHero**

In the `content` computed var, find:

```swift
NotesScreenTitle(
    "Hole \(round.currentHole)",
    subtitle: headerSubtitle
)
```

Replace with:

```swift
holeHero
holeCourseLabel
```

- [ ] **Step 3: Add runningTotal helper**

Add this private function below `labelColor(forNetDelta:)`:

```swift
private func runningTotal(for player: Player) -> String? {
    let posted = round.scores.filter {
        $0.player.id == player.id && $0.holeNumber < round.currentHole
    }
    guard !posted.isEmpty else { return nil }
    let totalStrokes = posted.reduce(0) { $0 + $1.strokes }
    let totalPar = posted.map(\.holeNumber).reduce(0) { $0 + round.parForHole($1) }
    let delta = totalStrokes - totalPar
    let deltaStr = delta == 0 ? "E" : (delta < 0 ? "\(delta)" : "+\(delta)")
    return "\(deltaStr) thru \(posted.count)"
}
```

- [ ] **Step 4: Update playerRow to show running total + glass card**

In `playerRow(_:)`, find the `VStack` inside the `HStack` that has the player name currently showing only the result label. Replace the name/label block with:

```swift
// Find this block inside the HStack in playerRow:
HStack(spacing: 10) {
    Text(label)
        .foregroundStyle(labelColor)
        .font(.system(.title3, design: .default).weight(.semibold))

    if received > 0 {
        Text("• Net \(netStrokes)")
            .foregroundStyle(NotesTheme.textSecondary)
            .font(.system(.body, design: .default).weight(.regular))
            .monospacedDigit()
    }
}
.lineLimit(1)

// Replace with:
VStack(alignment: .leading, spacing: 2) {
    HStack(spacing: 8) {
        Text(label)
            .foregroundStyle(labelColor)
            .font(.system(.title3, design: .default).weight(.semibold))

        if received > 0 {
            Text("Net \(netStrokes)")
                .foregroundStyle(NotesTheme.textSecondary)
                .font(.system(.subheadline, design: .default))
                .monospacedDigit()
        }
    }

    if let total = runningTotal(for: player) {
        Text(total)
            .font(.caption)
            .foregroundStyle(NotesTheme.textSecondary)
            .monospacedDigit()
    }
}
.lineLimit(1)
```

- [ ] **Step 5: Wrap playerRow in glass card**

In `playerRow(_:)`, find the closing modifiers of the Button:

```swift
.padding(.vertical, 16)
.contentShape(Rectangle())
```

Replace with:

```swift
.padding(.vertical, 14)
.padding(.horizontal, 16)
.background(
    RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 4)
)
.overlay(
    RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(NotesTheme.cardStroke, lineWidth: 1)
)
.contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
```

- [ ] **Step 6: Update playerList to use spacing instead of dividers**

Replace the `VStack(spacing: 0)` and its `ForEach` in `playerList`:

```swift
return VStack(spacing: 10) {
    ForEach(orderedPlayers, id: \.id) { player in
        playerRow(player)
            .padding(.horizontal, GSPUI.Spacing.insetX)
    }
}
```

- [ ] **Step 7: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add Views/LiveRound/LiveRoundView.swift
git commit -m "feat: Hole Hero header + glass player cards + running totals

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 7: Update LeaderboardView

**Files:**
- Modify: `Views/LiveRound/LeaderboardView.swift`

- [ ] **Step 1: Replace hardcoded dark colors in player rows**

Search `LeaderboardView.swift` for any `Color.white.opacity(` or `Color(white:` literals and replace:

| Find | Replace |
|---|---|
| `Color.white.opacity(0.35)` (position number) | `NotesTheme.textTertiary` |
| `Color.white.opacity(0.80)` (non-winner name) | `NotesTheme.textSecondary` |
| `Color.white` (winner name) | `NotesTheme.textPrimary` |
| `Color.white.opacity(0.75)` (non-winner score) | `NotesTheme.textSecondary` |
| `Color.white` (winner score) | `NotesTheme.textPrimary` |
| `Color.green.opacity(0.75)` | `NotesTheme.accent` |
| `Color.red.opacity(0.75)` | `Color.red` |
| `Color.white.opacity(0.45)` (even delta) | `NotesTheme.textTertiary` |

- [ ] **Step 2: Wrap each standings row in a glass card**

Find the `playerRow` function (or equivalent row builder). Add glass card background to the row's outermost container. The row currently returns an `HStack` with `.padding`. Update it to:

```swift
// After the final .padding(...) inside the row builder, add:
.background(
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 3)
)
.overlay(
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(NotesTheme.cardStroke, lineWidth: 1)
)
.padding(.horizontal, GSPUI.Spacing.insetX)
```

Also remove any `Divider()` calls between rows and replace the wrapping `VStack(spacing: 0)` with `VStack(spacing: 8)`.

- [ ] **Step 3: Update Finish Round pill to use accent fill with adaptive foreground**

Find the Finish Round button and ensure its label uses:

```swift
.foregroundStyle(Color(UIColor { t in
    t.userInterfaceStyle == .dark ? .black : .white
}))
```

- [ ] **Step 4: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Views/LiveRound/LeaderboardView.swift
git commit -m "feat: LeaderboardView adaptive colors + glass standing rows

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 8: Update RoundSetupView

**Files:**
- Modify: `Views/LiveRound/RoundSetupView.swift`

- [ ] **Step 1: Replace hardcoded dark colors**

Search `RoundSetupView.swift` for `Color.white.opacity(` and `Color.black` literals used for text/surfaces (not accent-fill logic). Replace:

| Find | Replace |
|---|---|
| `.foregroundStyle(Color.white)` | `.foregroundStyle(NotesTheme.textPrimary)` |
| `.foregroundStyle(Color.white.opacity(0.68))` | `.foregroundStyle(NotesTheme.textSecondary)` |
| `.foregroundStyle(Color.white.opacity(0.48))` | `.foregroundStyle(NotesTheme.textTertiary)` |
| `Color.white.opacity(0.10)` (background fills) | `Color.clear` then add `.notesCard()` modifier to the container instead |

- [ ] **Step 2: Update game type selector to glass cards with accent highlight**

Find the game type selection UI (likely a `ForEach` over `GameType.allCases` or a set of buttons). Each game type row/card should become:

```swift
// Wrap each game type option in:
VStack(alignment: .leading, spacing: 4) {
    Text(gameType.title)
        .gspFont(.rowTitle)
        .foregroundStyle(NotesTheme.textPrimary)
    Text(gameType.subtitle)
        .gspFont(.rowSubtitle)
        .foregroundStyle(NotesTheme.textSecondary)
}
.frame(maxWidth: .infinity, alignment: .leading)
.padding(16)
.background(
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(selectedGameType == gameType ? NotesTheme.accentSoft : Color.clear)
)
.overlay(
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(
            selectedGameType == gameType ? NotesTheme.accent : NotesTheme.cardStroke,
            lineWidth: selectedGameType == gameType ? 2 : 1
        )
)
.background(
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.ultraThinMaterial)
)
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Views/LiveRound/RoundSetupView.swift
git commit -m "feat: RoundSetupView adaptive colors + glass game-type cards

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 9: Update RoundsView + empty state

**Files:**
- Modify: `Views/Rounds/RoundsView.swift`

- [ ] **Step 1: Add leading icon to round rows**

Find where `RoundRow` or the row label is constructed. Each round row should use an icon. Find any `NotesChevronRowLabel` or equivalent row in `RoundsView` and add `icon: "flag.fill"`.

If rows are custom (not using `NotesChevronRowLabel`), add the icon circle pattern:

```swift
Image(systemName: "flag.fill")
    .font(.system(size: 14, weight: .semibold))
    .foregroundStyle(NotesTheme.accent)
    .frame(width: 32, height: 32)
    .background(Circle().fill(NotesTheme.accentSoft))
```

as the leading element in each row's `HStack`.

- [ ] **Step 2: Replace the `emptyState` view**

Find the `emptyState` computed var (or whatever is shown when `rounds.isEmpty`). Replace its content with:

```swift
private var emptyState: some View {
    VStack(spacing: 16) {
        Image(systemName: "flag.fill")
            .font(.system(size: 48, weight: .regular))
            .foregroundStyle(NotesTheme.textTertiary)

        Text("No Rounds Yet")
            .font(.title3.weight(.semibold))
            .foregroundStyle(NotesTheme.textPrimary)

        Text("Start a round from the home screen.")
            .font(.subheadline)
            .foregroundStyle(NotesTheme.textSecondary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 60)
}
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Views/Rounds/RoundsView.swift
git commit -m "feat: RoundsView icon rows + polished empty state

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 10: Update CoursesView + empty state

**Files:**
- Modify: `Views/Courses/CoursesView.swift`

- [ ] **Step 1: Add leading icon to course rows**

In each course row, add the icon circle as the leading element:

```swift
Image(systemName: "mappin.circle.fill")
    .font(.system(size: 14, weight: .semibold))
    .foregroundStyle(NotesTheme.accent)
    .frame(width: 32, height: 32)
    .background(Circle().fill(NotesTheme.accentSoft))
```

- [ ] **Step 2: Add/replace empty state**

Add or replace the empty state with:

```swift
private var emptyState: some View {
    VStack(spacing: 16) {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 48, weight: .regular))
            .foregroundStyle(NotesTheme.textTertiary)

        Text("No Courses Yet")
            .font(.title3.weight(.semibold))
            .foregroundStyle(NotesTheme.textPrimary)

        Text("Add a course to track par and stroke index.")
            .font(.subheadline)
            .foregroundStyle(NotesTheme.textSecondary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 60)
}
```

Show it when the courses list is empty (same pattern as RoundsView).

- [ ] **Step 3: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Views/Courses/CoursesView.swift
git commit -m "feat: CoursesView icon rows + polished empty state

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 11: Update PlayersView + empty state

**Files:**
- Modify: `Views/Players/PlayersView.swift`

- [ ] **Step 1: Add leading icon to player rows**

In each player row, add the icon circle as the leading element:

```swift
Image(systemName: "person.fill")
    .font(.system(size: 14, weight: .semibold))
    .foregroundStyle(NotesTheme.accent)
    .frame(width: 32, height: 32)
    .background(Circle().fill(NotesTheme.accentSoft))
```

- [ ] **Step 2: Add/replace empty state**

```swift
private var emptyState: some View {
    VStack(spacing: 16) {
        Image(systemName: "person.fill")
            .font(.system(size: 48, weight: .regular))
            .foregroundStyle(NotesTheme.textTertiary)

        Text("No Players Yet")
            .font(.title3.weight(.semibold))
            .foregroundStyle(NotesTheme.textPrimary)

        Text("Add players to speed up round setup.")
            .font(.subheadline)
            .foregroundStyle(NotesTheme.textSecondary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 60)
}
```

Show it when the player list is empty.

- [ ] **Step 3: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Views/Players/PlayersView.swift
git commit -m "feat: PlayersView icon rows + polished empty state

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 12: Update RoundSummaryCard

**Files:**
- Modify: `Views/LiveRound/RoundSummaryCard.swift`

> Note: `RoundSummaryCard` renders via `ImageRenderer` to a `UIImage` for sharing. `.ultraThinMaterial` is not renderable by `ImageRenderer` — keep solid fills here. Adapt only the color values.

- [ ] **Step 1: Replace hardcoded dark colors with adaptive equivalents**

Replace all literal `Color.white.opacity(...)` and `Color(white: 0.07)` values:

| Find | Replace |
|---|---|
| `Color(white: 0.07)` (card background) | `Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor(white: 0.07, alpha: 1) : UIColor(white: 0.97, alpha: 1) })` |
| `Color.white` (winner name/score) | `Color(UIColor { t in t.userInterfaceStyle == .dark ? .white : UIColor(red: 0.102, green: 0.180, blue: 0.102, alpha: 1) })` |
| `Color.white.opacity(0.80)` | `Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor(white:1,alpha:0.80) : UIColor(white:0,alpha:0.70) })` |
| `Color.white.opacity(0.55)` | `Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor(white:1,alpha:0.55) : UIColor(white:0,alpha:0.45) })` |
| `Color.white.opacity(0.35)` | `Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor(white:1,alpha:0.35) : UIColor(white:0,alpha:0.28) })` |
| `Color.white.opacity(0.30)` | `Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor(white:1,alpha:0.30) : UIColor(white:0,alpha:0.25) })` |
| `Color.white.opacity(0.25)` | `Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor(white:1,alpha:0.25) : UIColor(white:0,alpha:0.18) })` |
| `Color.white.opacity(0.12)` (stroke) | `NotesTheme.cardStroke` |
| `Color.white.opacity(0.10)` (divider) | `NotesTheme.divider` |
| `Color.white.opacity(0.07)` (row divider) | `NotesTheme.divider` |
| `Color.green.opacity(0.80)` | `Color.accentColor` |
| `Color.red.opacity(0.80)` | `Color.red` |
| `Color.white.opacity(0.45)` (even delta) | `Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor(white:1,alpha:0.45) : UIColor(white:0,alpha:0.35) })` |

- [ ] **Step 2: Add accent strip to header**

In `headerBlock`, update the background of the header `VStack` to include a subtle accent tint:

```swift
// Add to the headerBlock VStack:
.background(
    Rectangle()
        .fill(NotesTheme.accentSoft)
)
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/gvb/Desktop/GolfScorePro/GolfScorePro
xcodebuild -project GolfScorePro.xcodeproj -scheme GolfScorePro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Views/LiveRound/RoundSummaryCard.swift
git commit -m "feat: RoundSummaryCard adaptive colors + accent header strip

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** AccentColor ✓, NotesTheme adaptive ✓, Surface modifiers ✓, Dynamic Type ✓, HomeView glass CTA + icons ✓, Hole Hero ✓, Running totals ✓, Glass player cards ✓, LeaderboardView ✓, RoundSetupView ✓, Rounds/Courses/Players icons + empty states ✓, RoundSummaryCard ✓
- [x] **Placeholders:** None — all steps contain complete code
- [x] **Type consistency:** `NotesTheme.accentSoft` introduced in Task 1 and used in Tasks 4–11 ✓, `notesCard()`/`notesRowSurface()` updated in Task 1 and used throughout ✓, `GSPPrimaryPill.isGlass` introduced in Task 3 — callers in LiveRoundView need to pass `isGlass: true` for posted state (see Task 6)
- [x] **RoundSummaryCard solid-fill note** documented inline (ImageRenderer limitation)
- [x] **Phase ordering** explicit — Phase 2 tasks only start after Task 4 completes
