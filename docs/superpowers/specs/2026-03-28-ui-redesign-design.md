# GolfScorePro UI Redesign — Design Spec
_Date: 2026-03-28_

## Overview

Complete UI overhaul of GolfScorePro for iOS 26, targeting App Store release. The redesign moves from a dark-only "Notes-inspired" aesthetic to **Fairway Light** — an adaptive light/dark design language built on iOS 26 Liquid Glass materials, SF Pro Dynamic Type, and a golf-native green palette. All existing screens are updated; no new features are added.

---

## Design Decisions

| Decision | Choice | Reason |
|---|---|---|
| iOS target | iOS 26 | User has latest iPhone; enables `.ultraThinMaterial`, `.thinMaterial`, glass tab bar |
| Visual direction | Fairway Light | Adaptive light/dark, frosted glass on soft green gradient — feels like the course |
| Navigation | Home Hub (no tab bar) | Keeps "pro tool" focus, fewer taps to start a round |
| Scoring screen | Hole Hero | Giant hole number readable with gloves; running totals always visible |
| Monetization | Out of scope for this redesign | Deferred by user |

---

## 1. Design System

### 1.1 Palette — `GSPTheme` (replaces `NotesTheme`)

All colors are adaptive (light/dark). No hardcoded `Color.black` or `Color.white.opacity(...)` backgrounds.

| Token | Light Mode | Dark Mode |
|---|---|---|
| `bg` | `Color(hex: "#F0FAF0")` soft green-white | `Color(hex: "#0D1A0D")` deep forest |
| `bgGradient` | `LinearGradient` `#E8F5E9 → #F0FAF0 → #E0F2F1` | `LinearGradient` `#0A0A0A → #0D1A0D → #0A120A` |
| `card` | `.ultraThinMaterial` + white `0.55` overlay | `.ultraThinMaterial` + white `0.08` overlay |
| `cardStrong` | `.thinMaterial` + white `0.70` overlay | `.thinMaterial` + white `0.12` overlay |
| `cardStroke` | `white @ 0.9` | `white @ 0.14` |
| `divider` | `black @ 0.06` | `white @ 0.10` |
| `textPrimary` | `Color(hex: "#1A2E1A")` | `.white` |
| `textSecondary` | `black @ 0.55` | `white @ 0.68` |
| `textTertiary` | `black @ 0.35` | `white @ 0.48` |
| `accent` | `Color(hex: "#166534")` rich green | `Color(hex: "#4ADE80")` lime |
| `accentSoft` | `accent @ 0.12` | `accent @ 0.18` |

### 1.2 Typography — Dynamic Type

All hardcoded `font(.system(size: X))` calls replaced with Dynamic Type scales.

| Role | Scale | Weight |
|---|---|---|
| Screen title | `.largeTitle` | `.bold` |
| Screen subtitle | `.subheadline` | `.regular` |
| Section label | `.caption` | `.semibold` (uppercased) |
| Row title | `.body` | `.semibold` |
| Row subtitle | `.subheadline` | `.regular` |
| Row trailing | `.subheadline` | `.semibold` |
| Hole number hero | `.system(size: 72, weight: .black)` | fixed — glove-readable |
| Score number | `.system(size: 38, weight: .semibold)` | fixed — kept from existing |
| Post pill | `.title3` | `.semibold` |
| Chip label | `.caption2` | `.semibold` |

### 1.3 Surfaces

Two reusable surface modifiers replace all ad-hoc backgrounds:

```swift
// Glass card — standard content blocks
func gspCard(radius: CGFloat = 18) -> some View

// Glass row block — list containers
func gspListBlock() -> some View
```

Both use `.ultraThinMaterial` + a white stroke + `shadow(color: black@0.07, radius: 14, y: 4)`.

### 1.4 Spacing & Radius

Existing `GSPUI.Spacing` and `GSPUI.Radius` constants are kept. No changes needed — they are already well-structured.

---

## 2. Screens

### 2.1 Home (`HomeView`)

- Background: `bgGradient` ignoring safe area
- Hero title: "GolfScorePro" in `.largeTitle.bold`, `textPrimary`
- Subtitle: "Score fast. Stay focused." in `.subheadline`, `textSecondary`
- CTA pill: glass card with `accent`-tinted left border (4pt), title in `.title2.semibold`, subtitle in `.subheadline`; replaces flat `accent` fill
- Library block: `.gspListBlock()` with three rows (Rounds, Courses, Players), each with a leading SF Symbol in an `accentSoft` circle + `rowTitle` text + chevron
  - Rounds → `flag.fill`
  - Courses → `mappin.circle.fill`
  - Players → `person.fill`
- No tab bar

### 2.2 Live Round — Hole Hero (`LiveRoundView`)

**Hole Hero header** (replaces the topbar subtitle):
- Giant hole number: `72pt black weight`, `textPrimary`, left-aligned
- "HOLE" label: `.caption.semibold` uppercased, `textTertiary`, above the number
- Chips row (right-aligned, baseline-aligned with number): Par, SI, Yards — each a glass pill (`gspCard(radius:10)`) with value in `.headline.bold` and label in `.caption2`
- Course name: `.caption`, `textTertiary`, below hero row
- `···` menu button: top-right, `GSPIconPillButton` (unchanged)

**Player rows** (each is now an individual glass card):
- Avatar circle (unchanged)
- Name: `.body.semibold`, `textPrimary`
- Running total: `.caption`, `textSecondary` — e.g. `−3 thru 7`, `E thru 7`, `+5 thru 7`
- Score: `38pt semibold`, `textPrimary` (right)
- Result badge: `.caption.bold`, color-coded — birdie/eagle green, bogey/double red, par tertiary

**Bottom bar**: unchanged structure (← | Post Scores | →). Post button: `accent` fill when pending, `gspCard` glass when posted ("✓ Posted · Next Hole").

**Background**: `bgGradient` (adapts light/dark), replacing hardcoded `Color.black`.

### 2.3 Leaderboard (`LeaderboardView`)

- Screen title: "Standings", subtitle: course name
- Gross/Net toggle: glass segmented control (`.pickerStyle(.segmented)` with material background)
- Player rows: individual glass cards with:
  - Position number in `accentSoft` circle
  - Name + score in `.body.semibold`
  - Delta badge: `+3`, `−1`, `E` with green/red/tertiary tint
- Expandable hole-by-hole detail: unchanged behavior, glass sub-cards
- Finish Round pill: solid `accent` fill, `.title3.semibold`
- Background: `bgGradient`

### 2.4 Round Setup (`RoundSetupView`)

- Game type selector: 3-up glass card grid (Stroke Play / Match Play / Skins). Selected card gets `accent` border (2pt) + `accentSoft` background tint
- Players section: glass list block; player rows show team-color avatar + name + team badge
- Course section: glass list block; selected course shown with `checkmark` in `accent`
- Start Round pill: solid `accent` fill, full-width, bottom safe area inset
- Background: `bgGradient`

### 2.5 Rounds, Courses, Players (list screens)

All three screens follow the same pattern:
- `NotesScreenTitle` stays (already correct)
- List rows wrapped in `gspListBlock()`
- Leading icon in `accentSoft` circle:
  - Rounds: `flag.fill` + date + score trailing
  - Courses: `mappin.circle.fill` + hole count trailing
  - Players: `person.fill` + handicap trailing
- Row menu ("···") button: `GSPIconPillButton` (unchanged)
- Background: `bgGradient`

### 2.6 Empty States

Every list screen gets a centered empty state:
- SF Symbol (matching the screen's icon, large, `textTertiary`)
- Headline: e.g. "No Rounds Yet" in `.title3.semibold`
- Subheadline: e.g. "Start a round from the home screen." in `.subheadline`, `textSecondary`

### 2.7 Round Summary Card (`RoundSummaryCard`)

- Glass card with subtle `accentSoft` gradient header strip
- Score in `.largeTitle.bold`, `textPrimary`
- Course + date in `.subheadline`, `textSecondary`
- Per-player breakdown rows in glass sub-cards

---

## 3. Components to Update

| Component | Change |
|---|---|
| `NotesTheme` | Replaced by `GSPTheme` (adaptive palette) |
| `notesBackground()` | Replaced by `gspBackground()` (gradient, adaptive) |
| `notesCard()` / `notesRowSurface()` | Replaced by `gspCard()` / `gspListBlock()` (material-based) |
| `NotesScreenTitle` | Keep, update foreground colors to `GSPTheme` tokens |
| `NotesChevronRowLabel` | Add leading icon parameter |
| `GSPPrimaryPill` | Update to support glass variant (posted state) |
| `GSPSecondaryPill` | Update fill to `.ultraThinMaterial` |
| `GSPIconPillButton` | Keep — already uses `.ultraThinMaterial`, already correct |
| `GSPAvatarCircle` | Keep — already correct |
| `GSPToastHUD` | Update accent to adaptive |
| All view files | Replace `NotesTheme.*` → `GSPTheme.*`, `notesBackground()` → `gspBackground()` |

---

## 4. What Is NOT Changing

- Navigation structure (Home Hub, `NavigationStack`, no tab bar)
- Scoring logic, data models, domain engines
- Haptics
- SwiftData integration
- Existing spacing/radius tokens in `GSPUI`
- App icon (out of scope)
- Onboarding (out of scope)
- Monetization (out of scope)

---

## 5. Implementation Strategy

Parallel agent team, each owning one layer:

1. **Agent: Design System** — Create `GSPTheme`, update `gspCard`/`gspBackground` modifiers, update `GSPUI.Typography` to Dynamic Type, update shared components (`NotesScreenTitle`, `NotesChevronRowLabel`, pills)
2. **Agent: Live Round** — Implement Hole Hero header, glass player cards with running totals, updated bottom bar
3. **Agent: Home + Supporting Screens** — Update `HomeView`, `RoundsView`, `CoursesView`, `PlayersView` to `GSPTheme` + glass surfaces + leading icons + empty states
4. **Agent: Setup + Summary** — Update `RoundSetupView`, `LeaderboardView`, `RoundSummaryCard`

Agent 1 (Design System) must complete before Agents 2–4 start, since they depend on the new tokens.
