# GolfScorePro — Project Agent Memory

## What this project is

GolfScorePro is an iOS golf scoring app built with **SwiftUI** and **SwiftData**.
It supports Stroke Play, Match Play (Net Better Ball), and Skins, with optional
handicap adjustments. Players, courses, and rounds are persisted via SwiftData.

---

## Architecture

### Layer boundary rule — strictly enforced

| Layer | Location | Allowed imports |
|-------|----------|-----------------|
| Domain | `Domain/` | `Foundation` only — no SwiftUI, no SwiftData |
| Models | `Models/` | SwiftData `@Model` classes |
| Views | `Views/` | SwiftUI + domain types |
| Services | `Services/` | Foundation / UIKit |

**The single bridge point** between persistence and the domain layer is
`Domain/RoundInput+Bridge.swift`. It is the only domain file that may reference
SwiftData model types. All scoring engines operate on `RoundInput`, never on
`Round` directly.

### Domain engines (stateless enums)

- `StrokePlayEngine` — stroke play gross/net totals, deltas, per-hole results
- `HandicapAllocator` — SI-based stroke allocation
- `SkinsEngine` — skins with carry rules
- `NetBetterBallEngine` — team match play (Net Better Ball)

### Key domain value types

- `CourseLayout` — pars + stroke indices, 1-based hole lookup
- `PlayerCard` — lightweight player snapshot (id, name, handicap, optional team)
- `HoleScore` — playerID + holeNumber (1-based) + strokes
- `RoundInput` — complete round snapshot fed into all engines
- `LeaderboardRow` — engine output per player (gross/net totals and deltas)
- `HoleResult` — per-hole engine output for one player
- `HoleLabel` — display label enum for a hole delta

---

## Code style

- **Indentation:** 4 spaces
- **Naming:** PascalCase for types, camelCase for properties/methods
- **State:** `@State private var` for SwiftUI state, `let` for constants
- **Async:** Prefer Swift `async/await` over Combine
- **Safety:** No force unwrap. Validate at system boundaries only.
- **Simplicity:** No premature abstraction. Three similar lines > an abstraction used once.
- **Comments:** Only where logic is non-obvious. Do not add docstrings to untouched code.

## Testing framework

Use **Swift Testing** (`import Testing`, `@Test`, `#expect`) for all unit tests —
not XCTest. UI tests use XCUIAutomation.

Test files live in `GolfScoreProTests/`. Domain tests are in `ScoringEngineTests.swift`.

## SwiftUI constraints to remember

- `@ViewBuilder` functions cannot contain bare `let` / `var` declarations before
  a view-producing statement — this causes `"Type '()' cannot conform to 'View'"`.
  Fix: remove `@ViewBuilder` and add an explicit `return`, or extract computation
  to a plain (non-`@ViewBuilder`) helper.
- `ImageRenderer` must only receive plain value types. Never pass a SwiftData
  `@Model` object into it — accessing model properties inside the renderer triggers
  SwiftData faults and `uiImage` returns nil silently. Always snapshot model data
  into a plain struct on the main actor first.
