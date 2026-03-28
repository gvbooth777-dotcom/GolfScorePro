# Domain Layer — Agent Memory

All files in this directory are **pure Swift** (Foundation only). No SwiftUI.
No SwiftData. Engines are stateless enums with static methods.

---

## Gross vs Net — the fundamental rule

**Par is fixed.** Receiving handicap strokes reduces a player's score, not the par.

```
grossDelta = grossStrokes − par
netStrokes = max(1, grossStrokes − received)   // floored at 1 per hole
netDelta   = netStrokes − par                  // NOT netStrokes − (par − received)
```

For `buildRow` (cumulative across holes):
```
netTotal   = max(0, grossTotal − totalReceived)
netDelta   = netTotal − grossPar               // grossPar is FIXED
```

### The historical bug — do not reintroduce

Computing `netDelta = netStrokes − (par − received)` (i.e. reducing par by strokes
received) makes net mode produce **identical labels to gross mode** for any player
receiving strokes. This was the root cause of the net mode trust bug fixed in 2026.

**Concrete example** (par 4, player receives 1 stroke):

| Gross | Net | Correct netDelta | Wrong netDelta | Correct label |
|-------|-----|-----------------|----------------|---------------|
| 4     | 3   | 3 − 4 = **−1**  | 3 − 3 = 0      | BRD           |
| 5     | 4   | 4 − 4 = **0**   | 4 − 3 = +1     | PAR           |
| 6     | 5   | 5 − 4 = **+1**  | 5 − 3 = +2     | BGY           |
| 7     | 6   | 6 − 4 = **+2**  | 6 − 3 = +3     | DBL           |

---

## HoleLabel mapping

`HoleLabel.from(delta:)` → `HoleLabel` → `.text`:

| Delta | Label |
|-------|-------|
| ≤ −3  | `"-3"`, `"-4"`, … (numeric) |
| −2    | `"EAG"` |
| −1    | `"BRD"` |
| 0     | `"PAR"` |
| +1    | `"BGY"` |
| +2    | `"DBL"` |
| ≥ +3  | `"+3"`, `"+4"`, … (numeric) |

**Never** use `"DBL+"`. Double bogey is `"DBL"` (+2 exactly). Worse is `"+3"`, `"+4"`, etc.

---

## Handicap allocation (SI threshold algorithm)

`HandicapAllocator.strokesReceived(handicap:strokeIndex:)`:

```
received  = 0
threshold = strokeIndex
while handicap >= threshold:
    received  += 1
    threshold += 18
```

Key cases to remember:
- HCP 0 → receives nothing on any hole
- HCP 18 → receives exactly 1 stroke on every hole (18-hole course, SI 1–18)
- HCP 36 → receives exactly 2 strokes on every hole
- HCP 20, SI 2 → receives 2 strokes (20 ≥ 2, 20 ≥ 20, 20 < 38)
- HCP 10, SI 12 → receives 0 strokes (10 < 12)

`totalStrokesReceived(handicap:course:through:)` sums across holes 1…thru.

---

## thruHole computation

`StrokePlayEngine.computeThruHole(_:)` scans holes 1…N sequentially and breaks at
the first hole where **any player** is missing a score. Returns 0 if no hole is
fully complete. This means the displayed standing always reflects only fully-posted
holes — no partial holes.

---

## Skins rules

Implemented in `SkinsEngine`:
- One skin available per hole.
- `useHandicaps == false` → lowest unique **gross** score wins the hole.
- `useHandicaps == true` → lowest unique **net** score wins the hole.
- Tied lowest scores → skin **carries** to next hole.
- When a hole is won outright, that player collects the current skin plus all carried skins.
- If the round ends with an unresolved carry → `SkinsSummary.pendingCarry` is set.

---

## Match Play / Net Better Ball

Implemented in `NetBetterBallEngine`. Uses `TeamID` (`.a` / `.b`).

- Each hole is won by the team with the lower best-ball net score.
- Tied holes are halved.
- Running status tracked via `MatchStatus`:
  - `.allSquare(holesRemaining:)`
  - `.leading(side:by:holesRemaining:)`
  - `.won(winner:result:)` — result string e.g. `"3&2"`
  - `.halved` — all holes played, tied
- **Dormie** = lead equals holes remaining (cannot lose, can only win or halve).

---

## `LeaderboardRow` field semantics

```swift
struct LeaderboardRow {
    let grossTotal: Int   // sum of raw strokes
    let netTotal:   Int   // max(0, grossTotal − totalStrokesReceived)
    let grossDelta: Int   // grossTotal − grossPar
    let netDelta:   Int   // netTotal − grossPar  ← grossPar is FIXED
}
```

`netDelta` in a `LeaderboardRow` represents net total vs the **unadjusted** course
par through `thru` holes. A player at net even through 9 holes has `netDelta == 0`
regardless of how many strokes they received.

---

## `HoleResult` field semantics

```swift
struct HoleResult {
    let grossStrokes: Int  // raw strokes
    let received:     Int  // strokes received on this hole
    let netStrokes:   Int  // max(1, grossStrokes − received)
    let netPar:       Int  // = par (par is fixed; not reduced by received)
    let grossDelta:   Int  // grossStrokes − par
    let netDelta:     Int  // netStrokes − par  ← par is FIXED
}
```
