# LiveRound Views — Agent Memory

Files: `LeaderboardView.swift`, `LiveRoundView.swift`, `RoundSetupView.swift`,
`RoundSummaryCard.swift`.

---

## LeaderboardView — mode correctness rule

`mode: Mode` (`.gross` / `.net`) is the **single source of truth** for all derived
display. Every computed value shown in the UI must branch on this mode.

### Standard gate

```swift
let useNet = (mode == .net) && input.useHandicaps
```

`useNet` is false when handicaps are off, even if the Net pill is selected — there
are no net scores to show without handicaps.

### What `useNet` controls (exhaustive list)

| UI element | `useNet == false` | `useNet == true` |
|------------|-------------------|-----------------|
| Leaderboard total | `grossTotal` | `netTotal` |
| Leaderboard delta | `grossDelta` | `netDelta` |
| Subtitle label | `"vs Par"` | `"Net vs Par"` |
| Hole right-aligned score | `result.grossStrokes` | `result.netStrokes` |
| Hole delta label/color | `result.grossDelta` | `result.netDelta` |
| Player Stats buckets | `result.grossDelta` | `result.netDelta` |
| Collapsed hole badge | gross standing | net standing |
| Net indicator `"• Net N"` | shown | **hidden** (net score is already primary) |

If you find yourself using `result.grossStrokes` or `result.grossDelta` without
checking `useNet`, that is a bug.

---

## Player Stats section — label rules

Stat buckets use `HoleLabel.from(delta:).text`. Categories shown per player:

| Delta | Label |
|-------|-------|
| ≤ −2  | EAG   |
| −1    | BRD   |
| 0     | PAR   |
| +1    | BGY   |
| +2    | DBL   |
| ≥ +3  | +3, +4, … (numeric) |

Do **not** collapse +3 and above into `"DBL+"`. Show the numeric label.

---

## RoundSummaryCard — ImageRenderer rules

`ImageRenderer` (iOS 16+) renders SwiftUI views to `UIImage`. It runs off the
main actor and has no `ModelContext`. Passing a SwiftData `@Model` object into
the card and accessing its relationships inside the renderer will trigger
SwiftData faults — `uiImage` returns `nil` silently with no error.

**Always follow this pattern:**

```swift
// 1. Snapshot all data from the @Model on the main actor BEFORE touching ImageRenderer.
let data = RoundSummaryData(round: round)   // plain value type

// 2. Construct the card from the snapshot.
let card = RoundSummaryCard(data: data)

// 3. Now it is safe to render.
let renderer = ImageRenderer(content: card.padding(24))
renderer.scale = 3.0
let image = renderer.uiImage   // will not be nil
```

`RoundSummaryData` is a plain `struct` — no SwiftData types, no `@Model`.

---

## Share sheet presentation

`UIActivityViewController` must be presented on the **topmost** presented view
controller, not directly on the root. When a sheet (e.g. `roundCompleteSheet`)
is already presented, calling `present()` on the root is silently ignored by UIKit.

```swift
var top = rootViewController
while let next = top.presentedViewController { top = next }
top.present(activityVC, animated: true)
```

---

## `@ViewBuilder` constraints

Bare `let` / `var` declarations before a view-producing statement inside a
`@ViewBuilder` closure or function cause a compiler error:

```
Type '()' cannot conform to 'View'
```

Two fixes:
1. Remove `@ViewBuilder` from the function and add an explicit `return` before the root view.
2. Extract all computation into a plain (non-`@ViewBuilder`) helper that returns
   a plain value (e.g. `String?`), then use the result in a simple `if let` inside
   the `@ViewBuilder` context.

Option 2 is preferred when the computation is non-trivial or reusable.

---

## Spacing tokens (GSPUI.Spacing)

| Token | Value | Use |
|-------|-------|-----|
| `cardPad` | 16 | Interior card padding |
| `stripVPad` | 12 | Vertical padding for status strips (top) |
| `holeRowVPad` | 12 | Compact row vertical padding (bottom) |
| `sectionVStack` | 16 | VStack spacing between sections |
| `insetX` | 18 | Horizontal insets |
| `rowVPad` | 16 | List row vertical padding |

Use these tokens instead of raw numeric padding values. Do not use `26` for bottom
pill padding — use `28`.
