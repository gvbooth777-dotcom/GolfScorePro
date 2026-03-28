//
//  ScoringEngineTests.swift
//  GolfScoreProTests
//

import Testing
@testable import GolfScorePro

// MARK: - Test fixtures

/// 9-hole course: pars [4,3,5,4,4,3,4,5,4] (total 36), SI = 1..9
private let nineHolePars    = [4, 3, 5, 4, 4, 3, 4, 5, 4]
private let nineHoleSI      = [1, 2, 3, 4, 5, 6, 7, 8, 9]
private let nineHoleCourse  = CourseLayout(pars: nineHolePars, strokeIndices: nineHoleSI)

/// 18-hole course: all par 4, SI = 1..18
private let eighteenHolePars    = Array(repeating: 4, count: 18)
private let eighteenHoleSI      = Array(1...18)
private let eighteenHoleCourse  = CourseLayout(pars: eighteenHolePars, strokeIndices: eighteenHoleSI)

private func makePlayer(name: String = "Test", handicap: Int = 0) -> PlayerCard {
    PlayerCard(id: UUID(), name: name, handicap: handicap)
}

/// Build HoleScore array from a strokes list (hole 1 = index 0).
private func makeScores(playerID: UUID, strokes: [Int]) -> [HoleScore] {
    strokes.enumerated().map { idx, s in
        HoleScore(playerID: playerID, holeNumber: idx + 1, strokes: s)
    }
}

// MARK: - CourseLayout

struct CourseLayoutTests {

    @Test func parLookupInBounds() {
        #expect(nineHoleCourse.par(for: 1) == 4)
        #expect(nineHoleCourse.par(for: 2) == 3)
        #expect(nineHoleCourse.par(for: 3) == 5)
        #expect(nineHoleCourse.par(for: 9) == 4)
    }

    @Test func parOutOfRangeDefaultsFour() {
        #expect(nineHoleCourse.par(for: 0) == 4)
        #expect(nineHoleCourse.par(for: 10) == 4)
        #expect(nineHoleCourse.par(for: -1) == 4)
    }

    @Test func strokeIndexLookupInBounds() {
        #expect(nineHoleCourse.strokeIndex(for: 1) == 1)
        #expect(nineHoleCourse.strokeIndex(for: 5) == 5)
        #expect(nineHoleCourse.strokeIndex(for: 9) == 9)
    }

    @Test func totalParNineHoles() {
        // [4,3,5,4,4,3,4,5,4] = 36
        #expect(nineHoleCourse.totalPar == 36)
    }

    @Test func totalParEighteenHoles() {
        // 18 × 4 = 72
        #expect(eighteenHoleCourse.totalPar == 72)
    }

    @Test func holeCount() {
        #expect(nineHoleCourse.holeCount == 9)
        #expect(eighteenHoleCourse.holeCount == 18)
    }
}

// MARK: - HandicapAllocator

struct HandicapAllocatorTests {

    @Test func zeroHandicapReceivesNothing() {
        #expect(HandicapAllocator.strokesReceived(handicap: 0, strokeIndex: 1) == 0)
        #expect(HandicapAllocator.strokesReceived(handicap: 0, strokeIndex: 18) == 0)
    }

    @Test func handicapBelowSIReceivesNothing() {
        // HCP 5, SI 8 → 5 < 8 → 0
        #expect(HandicapAllocator.strokesReceived(handicap: 5, strokeIndex: 8) == 0)
    }

    @Test func handicapEqualToSIReceivesOne() {
        // HCP 8, SI 8 → 8 >= 8 → 1; 8 < 26 → stop
        #expect(HandicapAllocator.strokesReceived(handicap: 8, strokeIndex: 8) == 1)
    }

    @Test func handicapAboveSIReceivesOne() {
        // HCP 10, SI 8 → 10 >= 8 → 1; 10 < 26 → stop
        #expect(HandicapAllocator.strokesReceived(handicap: 10, strokeIndex: 8) == 1)
    }

    @Test func secondPassCoversDoubleStroke() {
        // HCP 20, SI 2 → 20 >= 2 → 1; 20 >= 20 → 2; 20 < 38 → stop
        #expect(HandicapAllocator.strokesReceived(handicap: 20, strokeIndex: 2) == 2)
    }

    @Test func handicap36OnSI1() {
        // 36 >= 1 → 1; 36 >= 19 → 2; 36 < 37 → stop
        #expect(HandicapAllocator.strokesReceived(handicap: 36, strokeIndex: 1) == 2)
    }

    @Test func handicap36OnSI18() {
        // 36 >= 18 → 1; 36 >= 36 → 2; 36 < 54 → stop
        #expect(HandicapAllocator.strokesReceived(handicap: 36, strokeIndex: 18) == 2)
    }

    @Test func handicap18ReceivesExactlyOneOnEveryHole() {
        // HCP 18 covers exactly one full pass on any SI 1..18
        for si in 1...18 {
            #expect(
                HandicapAllocator.strokesReceived(handicap: 18, strokeIndex: si) == 1,
                "SI \(si) should yield 1 stroke for HCP 18"
            )
        }
    }

    @Test func totalStrokesReceivedNineHoleFullRound() {
        // HCP 5, 9-hole course SI 1..9
        // Receives on SI 1,2,3,4,5 → 5 strokes total
        let total = HandicapAllocator.totalStrokesReceived(
            handicap: 5,
            course: nineHoleCourse,
            through: 9
        )
        #expect(total == 5)
    }

    @Test func totalStrokesReceivedPartialRound() {
        // HCP 5, through hole 3 only (SI 1,2,3) → 3
        let total = HandicapAllocator.totalStrokesReceived(
            handicap: 5,
            course: nineHoleCourse,
            through: 3
        )
        #expect(total == 3)
    }

    @Test func totalStrokesZeroThroughHole() {
        // through: 0 → 0 received
        let total = HandicapAllocator.totalStrokesReceived(
            handicap: 18,
            course: nineHoleCourse,
            through: 0
        )
        #expect(total == 0)
    }
}

// MARK: - StrokePlayEngine — thru-hole

struct StrokePlayEngineThruHoleTests {

    @Test func thruHoleNoScores() {
        let player = makePlayer()
        let input = RoundInput(
            course: nineHoleCourse,
            players: [player],
            scores: [],
            useHandicaps: false,
            gameFormat: .strokePlay
        )
        #expect(StrokePlayEngine.computeThruHole(input) == 0)
    }

    @Test func thruHoleNoPlayers() {
        let input = RoundInput(
            course: nineHoleCourse,
            players: [],
            scores: [],
            useHandicaps: false,
            gameFormat: .strokePlay
        )
        #expect(StrokePlayEngine.computeThruHole(input) == 0)
    }

    @Test func thruHoleOnePlayerAllNinePosted() {
        let player = makePlayer()
        let scores = makeScores(playerID: player.id, strokes: nineHolePars)
        let input = RoundInput(
            course: nineHoleCourse,
            players: [player],
            scores: scores,
            useHandicaps: false,
            gameFormat: .strokePlay
        )
        #expect(StrokePlayEngine.computeThruHole(input) == 9)
    }

    @Test func thruHoleBreaksOnFirstGap() {
        let player = makePlayer()
        // Holes 1 and 2 only; hole 3 missing
        let scores = makeScores(playerID: player.id, strokes: [4, 3])
        let input = RoundInput(
            course: nineHoleCourse,
            players: [player],
            scores: scores,
            useHandicaps: false,
            gameFormat: .strokePlay
        )
        #expect(StrokePlayEngine.computeThruHole(input) == 2)
    }

    @Test func thruHoleTwoPlayersBothComplete() {
        let p1 = makePlayer(name: "Alice")
        let p2 = makePlayer(name: "Bob")
        let scores = makeScores(playerID: p1.id, strokes: nineHolePars)
                   + makeScores(playerID: p2.id, strokes: nineHolePars)
        let input = RoundInput(
            course: nineHoleCourse,
            players: [p1, p2],
            scores: scores,
            useHandicaps: false,
            gameFormat: .strokePlay
        )
        #expect(StrokePlayEngine.computeThruHole(input) == 9)
    }

    @Test func thruHoleTwoPlayersOnePlayerMissingHole2() {
        let p1 = makePlayer(name: "Alice")
        let p2 = makePlayer(name: "Bob")
        // Both have hole 1; only p1 has hole 2
        let scores = [
            HoleScore(playerID: p1.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: p2.id, holeNumber: 1, strokes: 5),
            HoleScore(playerID: p1.id, holeNumber: 2, strokes: 3),
        ]
        let input = RoundInput(
            course: nineHoleCourse,
            players: [p1, p2],
            scores: scores,
            useHandicaps: false,
            gameFormat: .strokePlay
        )
        #expect(StrokePlayEngine.computeThruHole(input) == 1)
    }
}

// MARK: - StrokePlayEngine — buildRow

struct StrokePlayEngineBuildRowTests {

    @Test func buildRowGrossOnlyNoHandicap() {
        let player = makePlayer(name: "Alice", handicap: 0)
        // 3 holes: strokes [5, 3, 6], pars [4, 3, 5] → gross 14, par 12, delta +2
        let scores = makeScores(playerID: player.id, strokes: [5, 3, 6])
        let input = RoundInput(
            course: nineHoleCourse,
            players: [player],
            scores: scores,
            useHandicaps: false,
            gameFormat: .strokePlay
        )
        let row = StrokePlayEngine.buildRow(for: player, through: 3, input: input)
        #expect(row.grossTotal == 14)
        #expect(row.grossDelta == 2)
        #expect(row.netTotal == 14)   // no handicap applied
        #expect(row.netDelta == 2)
    }

    @Test func buildRowWithHandicapAtPar() {
        let player = makePlayer(name: "Bob", handicap: 5)
        // 9 holes at par: strokes match pars → grossTotal = 36
        // HCP 5, SI 1..9: receives on holes 1-5 → 5 strokes received
        // netTotal = max(0, 36-5) = 31
        // netDelta = netTotal - grossPar = 31-36 = -5
        // (playing at par gross earns -5 in net because handicap strokes count vs fixed par)
        let scores = makeScores(playerID: player.id, strokes: nineHolePars)
        let input = RoundInput(
            course: nineHoleCourse,
            players: [player],
            scores: scores,
            useHandicaps: true,
            gameFormat: .strokePlay
        )
        let row = StrokePlayEngine.buildRow(for: player, through: 9, input: input)
        #expect(row.grossTotal == 36)
        #expect(row.grossDelta == 0)
        #expect(row.netTotal == 31)
        #expect(row.netDelta == -5)
    }

    @Test func buildRowHandicapDisabledIgnoresHandicap() {
        let player = makePlayer(name: "Carol", handicap: 18)
        let scores = makeScores(playerID: player.id, strokes: nineHolePars)
        let input = RoundInput(
            course: nineHoleCourse,
            players: [player],
            scores: scores,
            useHandicaps: false,  // handicaps off
            gameFormat: .strokePlay
        )
        let row = StrokePlayEngine.buildRow(for: player, through: 9, input: input)
        // Gross and net must be identical when useHandicaps is false
        #expect(row.grossTotal == row.netTotal)
        #expect(row.grossDelta == row.netDelta)
    }

    @Test func buildRowThruZeroReturnsZeros() {
        let player = makePlayer()
        let input = RoundInput(
            course: nineHoleCourse,
            players: [player],
            scores: [],
            useHandicaps: false,
            gameFormat: .strokePlay
        )
        let row = StrokePlayEngine.buildRow(for: player, through: 0, input: input)
        #expect(row.grossTotal == 0)
        #expect(row.grossDelta == 0)
        #expect(row.netTotal == 0)
        #expect(row.netDelta == 0)
    }
}

// MARK: - StrokePlayEngine — leaderboard ordering

struct StrokePlayEngineLeaderboardTests {

    @Test func leaderboardSortsByGrossDeltaAscending() {
        let p1 = makePlayer(name: "Alice", handicap: 0)
        let p2 = makePlayer(name: "Bob", handicap: 0)
        // Alice: 5+3+5=13, par=12, delta=+1
        // Bob:   4+3+5=12, par=12, delta= 0
        let scores = makeScores(playerID: p1.id, strokes: [5, 3, 5])
                   + makeScores(playerID: p2.id, strokes: [4, 3, 5])
        let input = RoundInput(
            course: nineHoleCourse,
            players: [p1, p2],
            scores: scores,
            useHandicaps: false,
            gameFormat: .strokePlay
        )
        let rows = StrokePlayEngine.buildRows(for: input, through: 3)
            .sorted { $0.grossDelta < $1.grossDelta }
        #expect(rows[0].name == "Bob")
        #expect(rows[1].name == "Alice")
    }

    @Test func leaderboardTiebreakByTotal() {
        let p1 = makePlayer(name: "Alice", handicap: 0)
        let p2 = makePlayer(name: "Bob", handicap: 0)
        // Same strokes → same delta → same total → alphabetical
        let scores = makeScores(playerID: p1.id, strokes: [4, 3, 5])
                   + makeScores(playerID: p2.id, strokes: [4, 3, 5])
        let input = RoundInput(
            course: nineHoleCourse,
            players: [p1, p2],
            scores: scores,
            useHandicaps: false,
            gameFormat: .strokePlay
        )
        let rows = StrokePlayEngine.buildRows(for: input, through: 3)
            .sorted {
                if $0.grossDelta != $1.grossDelta { return $0.grossDelta < $1.grossDelta }
                if $0.grossTotal != $1.grossTotal { return $0.grossTotal < $1.grossTotal }
                return $0.name < $1.name
            }
        #expect(rows[0].name == "Alice")
        #expect(rows[1].name == "Bob")
    }
}

// MARK: - StrokePlayEngine — holeResult

struct StrokePlayEngineHoleResultTests {

    @Test func holeResultWithOneStrokeReceived() {
        let player = makePlayer(name: "Alice", handicap: 10)
        // Hole 1: par 4, SI 1. HCP 10 >= 1 → received = 1. Strokes = 5.
        // netStrokes = max(1, 5-1) = 4
        // netPar = par = 4 (par is fixed; receiving strokes doesn't reduce it)
        // grossDelta = 5-4 = +1
        // netDelta = netStrokes - par = 4-4 = 0  (net PAR, not gross bogey)
        let result = StrokePlayEngine.holeResult(
            for: player,
            hole: 1,
            strokes: 5,
            course: nineHoleCourse,
            useHandicaps: true
        )
        #expect(result.received == 1)
        #expect(result.netStrokes == 4)
        #expect(result.netPar == 4)
        #expect(result.grossDelta == 1)
        #expect(result.netDelta == 0)
    }

    @Test func holeResultNetStrokesFlooredAtOne() {
        let player = makePlayer(name: "Bob", handicap: 20)
        // Hole 1: par 4, SI 1. HCP 20 → received = 2.
        // Strokes = 1 (hole-in-one).
        // netStrokes = max(1, 1-2) = max(1, -1) = 1
        // netPar = par = 4 (par is fixed)
        // grossDelta = 1-4 = -3
        // netDelta = netStrokes - par = 1-4 = -3
        let result = StrokePlayEngine.holeResult(
            for: player,
            hole: 1,
            strokes: 1,
            course: nineHoleCourse,
            useHandicaps: true
        )
        #expect(result.netStrokes == 1)
        #expect(result.netPar == 4)
        #expect(result.grossDelta == -3)
        #expect(result.netDelta == -3)
    }

    @Test func holeResultHandicapsOff() {
        let player = makePlayer(name: "Carol", handicap: 18)
        // useHandicaps = false → received must be 0
        let result = StrokePlayEngine.holeResult(
            for: player,
            hole: 1,
            strokes: 5,
            course: nineHoleCourse,
            useHandicaps: false
        )
        #expect(result.received == 0)
        #expect(result.netStrokes == result.grossStrokes)
    }
}

// MARK: - HoleLabel

struct HoleLabelTests {

    @Test func standardLabels() {
        #expect(HoleLabel.from(delta: -2).text == "EAG")
        #expect(HoleLabel.from(delta: -1).text == "BRD")
        #expect(HoleLabel.from(delta:  0).text == "PAR")
        #expect(HoleLabel.from(delta:  1).text == "BGY")
        #expect(HoleLabel.from(delta:  2).text == "DBL")
    }

    @Test func largeBogeyUsesPlus() {
        #expect(HoleLabel.from(delta: 3).text == "+3")
        #expect(HoleLabel.from(delta: 5).text == "+5")
    }

    @Test func tripleEagleAndBeyondUsesNumeric() {
        #expect(HoleLabel.from(delta: -3).text == "-3")
        #expect(HoleLabel.from(delta: -4).text == "-4")
    }
}

// MARK: - Phase 2 fixtures

/// All-par-4, 9-hole course with SI 1..9.
private let p2Course = nineHoleCourse

// 4 players: A1 (hcp 8), A2 (hcp 12), B1 (hcp 4), B2 (hcp 0)
// Lowest hcp in group = 0 (B2).
// Playing handicaps: A1=8, A2=12, B1=4, B2=0.
private func makeP2Players() -> (a1: PlayerCard, a2: PlayerCard, b1: PlayerCard, b2: PlayerCard) {
    let a1 = PlayerCard(id: UUID(), name: "Alice",   handicap: 8,  team: .a)
    let a2 = PlayerCard(id: UUID(), name: "Bob",     handicap: 12, team: .a)
    let b1 = PlayerCard(id: UUID(), name: "Carol",   handicap: 4,  team: .b)
    let b2 = PlayerCard(id: UUID(), name: "Dave",    handicap: 0,  team: .b)
    return (a1, a2, b1, b2)
}

// Helpers

private func makeTeamInput(
    players: [PlayerCard],
    scoresPerPlayer: [(UUID, [Int])],
    holeCount: Int = 9
) -> RoundInput {
    let pars = Array(repeating: 4, count: holeCount)
    let si   = Array(1...holeCount)
    let course = CourseLayout(pars: pars, strokeIndices: si)
    var allScores: [HoleScore] = []
    for (pid, strokes) in scoresPerPlayer {
        allScores += makeScores(playerID: pid, strokes: strokes)
    }
    return RoundInput(
        course: course,
        players: players,
        scores: allScores,
        useHandicaps: true,
        gameFormat: .matchPlay
    )
}

// MARK: - TeamID

struct TeamIDTests {

    @Test func opponentOfAisB() {
        #expect(TeamID.a.opponent == .b)
    }

    @Test func opponentOfBisA() {
        #expect(TeamID.b.opponent == .a)
    }

    @Test func labelIsFormatted() {
        #expect(TeamID.a.label == "Team A")
        #expect(TeamID.b.label == "Team B")
    }
}

// MARK: - TeamAggregator

struct TeamAggregatorTests {

    @Test func bestBallPicksLowestNet() {
        // Net scores: [5, 3] → best = 3
        let result = TeamAggregator.bestBall(team: .a, netStrokes: [5, 3], grossStrokes: [6, 4])
        #expect(result?.netStrokes == 3)
        #expect(result?.grossStrokes == 4)
    }

    @Test func bestBallTieBreaksOnGross() {
        // Tied net 4/4 — gross [5, 4] → pick index 1 (gross 4)
        let result = TeamAggregator.bestBall(team: .a, netStrokes: [4, 4], grossStrokes: [5, 4])
        #expect(result?.netStrokes == 4)
        #expect(result?.grossStrokes == 4)
    }

    @Test func bestBallEmptyReturnsNil() {
        let result = TeamAggregator.bestBall(team: .a, netStrokes: [], grossStrokes: [])
        #expect(result == nil)
    }

    @Test func bestBallMismatchedArrayReturnsNil() {
        let result = TeamAggregator.bestBall(team: .a, netStrokes: [3], grossStrokes: [])
        #expect(result == nil)
    }

    @Test func sumAllAddsValues() {
        let result = TeamAggregator.sumAll(team: .b, netStrokes: [3, 4], grossStrokes: [4, 5])
        #expect(result?.netStrokes == 7)
        #expect(result?.grossStrokes == 9)
    }

    @Test func sumAllEmptyReturnsNil() {
        let result = TeamAggregator.sumAll(team: .b, netStrokes: [], grossStrokes: [])
        #expect(result == nil)
    }
}

// MARK: - MatchStatus

struct MatchStatusTests {

    @Test func allSquareStatusText() {
        let s = MatchStatus.allSquare(holesRemaining: 5)
        #expect(s.statusText == "AS")
        #expect(!s.isDormie)
    }

    @Test func leadingStatusText() {
        let s = MatchStatus.leading(side: .a, by: 2, holesRemaining: 4)
        #expect(s.statusText == "2 UP (Team A)")
        #expect(!s.isDormie)
    }

    @Test func dormieDetection() {
        // Leading 2 up with 2 holes left = dormie.
        let s = MatchStatus.leading(side: .b, by: 2, holesRemaining: 2)
        #expect(s.isDormie)
    }

    @Test func notDormieWhenLeadLessThanRemaining() {
        let s = MatchStatus.leading(side: .a, by: 1, holesRemaining: 3)
        #expect(!s.isDormie)
    }

    @Test func wonStatusText() {
        let s = MatchStatus.won(winner: .a, result: "3&2")
        #expect(s.statusText == "3&2")
        #expect(!s.isDormie)
    }

    @Test func halvedStatusText() {
        let s = MatchStatus.halved
        #expect(s.statusText == "Halved")
        #expect(!s.isDormie)
    }
}

// MARK: - HandicapDifference allocation

struct HandicapDifferenceTests {

    /// v1 rule: playing handicap = full - min, strokes allocated by SI.
    /// Players: A1 hcp 8, A2 hcp 12, B1 hcp 4, B2 hcp 0.
    /// Min = 0. Playing: A1=8, A2=12, B1=4, B2=0.
    @Test func playingHandicapsComputedAsFullMinusMin() {
        let (a1, a2, b1, b2) = makeP2Players()
        let players = [a1, a2, b1, b2]
        let minHcp = players.map(\.handicap).min() ?? 0
        #expect(minHcp == 0)

        let ph = Dictionary(uniqueKeysWithValues: players.map { ($0.id, max(0, $0.handicap - minHcp)) })
        #expect(ph[a1.id] == 8)
        #expect(ph[a2.id] == 12)
        #expect(ph[b1.id] == 4)
        #expect(ph[b2.id] == 0)
    }

    /// A1 playing hcp 8, hole SI=1 → receives 1 stroke (8 >= 1, 8 < 19).
    @Test func a1ReceivesOneStrokeOnSIOne() {
        #expect(HandicapAllocator.strokesReceived(handicap: 8, strokeIndex: 1) == 1)
    }

    /// A2 playing hcp 12, hole SI=8 → receives 1 stroke (12 >= 8, 12 < 26).
    @Test func a2ReceivesStrokeOnSIEight() {
        #expect(HandicapAllocator.strokesReceived(handicap: 12, strokeIndex: 8) == 1)
    }

    /// A2 playing hcp 12, hole SI=13 → receives 0 strokes (12 < 13).
    @Test func a2NoStrokeOnSIThirteen() {
        #expect(HandicapAllocator.strokesReceived(handicap: 12, strokeIndex: 13) == 0)
    }

    /// B2 playing hcp 0 → receives 0 strokes on any hole.
    @Test func b2ZeroHandicapNoStrokes() {
        for si in 1...18 {
            #expect(HandicapAllocator.strokesReceived(handicap: 0, strokeIndex: si) == 0)
        }
    }
}

// MARK: - NetBetterBallEngine

struct NetBetterBallEngineTests {

    // Convenience: 4 players, all score the same gross on each hole (par 4 course).
    // A1 hcp 8, A2 hcp 12, B1 hcp 4, B2 hcp 0. Min hcp = 0.
    // Playing hcps: A1=8, A2=12, B1=4, B2=0.
    //
    // Hole 1 SI=1:
    //   A1 receives 1 stroke → net = gross - 1
    //   A2 receives 1 stroke → net = gross - 1
    //   B1 receives 1 stroke → net = gross - 1
    //   B2 receives 0 strokes → net = gross
    //
    // If all post gross=4:
    //   A best ball net = 3, B best ball net = min(3, 4) = 3 → Halved

    private func allFourInput(strokes: Int = 4, holes: Int = 1) -> (RoundInput, PlayerCard, PlayerCard, PlayerCard, PlayerCard) {
        let (a1, a2, b1, b2) = makeP2Players()
        let allPlayers = [a1, a2, b1, b2]
        let scores: [(UUID, [Int])] = [
            (a1.id, Array(repeating: strokes, count: holes)),
            (a2.id, Array(repeating: strokes, count: holes)),
            (b1.id, Array(repeating: strokes, count: holes)),
            (b2.id, Array(repeating: strokes, count: holes))
        ]
        let input = makeTeamInput(players: allPlayers, scoresPerPlayer: scores, holeCount: holes)
        return (input, a1, a2, b1, b2)
    }

    @Test func returnsNilForNoScores() {
        let (a1, a2, b1, b2) = makeP2Players()
        let input = makeTeamInput(players: [a1, a2, b1, b2], scoresPerPlayer: [], holeCount: 9)
        #expect(NetBetterBallEngine.compute(input) == nil)
    }

    @Test func returnsNilIfNoTeamB() {
        let (a1, a2, _, _) = makeP2Players()
        let input = makeTeamInput(
            players: [a1, a2],
            scoresPerPlayer: [
                (a1.id, [5]),
                (a2.id, [5])
            ]
        )
        #expect(NetBetterBallEngine.compute(input) == nil)
    }

    @Test func halvedHoleAllSquare() {
        // All gross=4 on hole 1, all SI-eligible players receive net 3 (except B2 net 4).
        // Team A best ball = 3, Team B best ball = min(3,4) = 3 → halved.
        let (input, _, _, _, _) = allFourInput(strokes: 4, holes: 1)
        let summary = NetBetterBallEngine.compute(input)
        #expect(summary != nil)
        #expect(summary?.holesWonA == 0)
        #expect(summary?.holesWonB == 0)
        #expect(summary?.holesHalved == 1)
        if case .allSquare = summary?.status { } else {
            #expect(Bool(false), "Expected allSquare status")
        }
    }

    @Test func teamAWinsHole() {
        // Give A players a birdie (3) and B players bogey (5).
        // Hole 1, SI=1: A1 net=2, A2 net=2; B1 net=4, B2 net=5.
        // A best ball=2, B best ball=4 → A wins.
        let (a1, a2, b1, b2) = makeP2Players()
        let input = makeTeamInput(
            players: [a1, a2, b1, b2],
            scoresPerPlayer: [
                (a1.id, [3]),
                (a2.id, [3]),
                (b1.id, [5]),
                (b2.id, [5])
            ],
            holeCount: 1
        )
        let summary = NetBetterBallEngine.compute(input)
        #expect(summary?.holesWonA == 1)
        #expect(summary?.holesWonB == 0)
    }

    @Test func teamBWinsHole() {
        let (a1, a2, b1, b2) = makeP2Players()
        let input = makeTeamInput(
            players: [a1, a2, b1, b2],
            scoresPerPlayer: [
                (a1.id, [5]),
                (a2.id, [5]),
                (b1.id, [3]),
                (b2.id, [3])
            ],
            holeCount: 1
        )
        let summary = NetBetterBallEngine.compute(input)
        #expect(summary?.holesWonA == 0)
        #expect(summary?.holesWonB == 1)
    }

    @Test func matchProgression3Holes() {
        // Hole 1: A wins (birdie vs bogey), Hole 2: halved, Hole 3: B wins.
        // Expected final: all square.
        let (a1, a2, b1, b2) = makeP2Players()
        // h1: A birdie (3), B bogey (5)
        // h2: all par (4)
        // h3: A bogey (5), B birdie (3)
        let input = makeTeamInput(
            players: [a1, a2, b1, b2],
            scoresPerPlayer: [
                (a1.id, [3, 4, 5]),
                (a2.id, [3, 4, 5]),
                (b1.id, [5, 4, 3]),
                (b2.id, [5, 4, 3])
            ],
            holeCount: 3
        )
        let summary = NetBetterBallEngine.compute(input)
        #expect(summary?.holesWonA == 1)
        #expect(summary?.holesWonB == 1)
        #expect(summary?.holesHalved == 1)
        if case .allSquare = summary?.status { } else {
            #expect(Bool(false), "Expected allSquare after 3 holes")
        }
    }

    @Test func earlyFinishResult() {
        // 4-hole course. A wins holes 1, 2, 3. After hole 3: A leads 3-0 with 1 hole left → 3&1.
        let (a1, a2, b1, b2) = makeP2Players()
        let input = makeTeamInput(
            players: [a1, a2, b1, b2],
            scoresPerPlayer: [
                (a1.id, [3, 3, 3, 4]),
                (a2.id, [3, 3, 3, 4]),
                (b1.id, [5, 5, 5, 4]),
                (b2.id, [5, 5, 5, 4])
            ],
            holeCount: 4
        )
        let summary = NetBetterBallEngine.compute(input)
        if case .won(let winner, let result) = summary?.status {
            #expect(winner == .a)
            #expect(result == "3&1")
        } else {
            #expect(Bool(false), "Expected won status")
        }
    }

    @Test func dormieDetectedInSummary() {
        // 4-hole course. A wins holes 1 and 2 → leads 2-0, 2 holes left.
        // After hole 2: leading 2 up with 2 remaining = dormie.
        let (a1, a2, b1, b2) = makeP2Players()
        // Only post 2 holes worth of scores.
        let input = makeTeamInput(
            players: [a1, a2, b1, b2],
            scoresPerPlayer: [
                (a1.id, [3, 3]),
                (a2.id, [3, 3]),
                (b1.id, [5, 5]),
                (b2.id, [5, 5])
            ],
            holeCount: 4
        )
        let summary = NetBetterBallEngine.compute(input)
        #expect(summary?.status.isDormie == true)
    }

    @Test func halvedMatchAfterAllHoles() {
        // 2-hole course. A wins hole 1, B wins hole 2 → final: halved.
        let (a1, a2, b1, b2) = makeP2Players()
        let input = makeTeamInput(
            players: [a1, a2, b1, b2],
            scoresPerPlayer: [
                (a1.id, [3, 5]),
                (a2.id, [3, 5]),
                (b1.id, [5, 3]),
                (b2.id, [5, 3])
            ],
            holeCount: 2
        )
        let summary = NetBetterBallEngine.compute(input)
        // After all holes tied 1-1 → halved.
        if case .halved = summary?.status { } else {
            // Allow allSquare(holesRemaining:0) as equivalent.
            if case .allSquare(let rem) = summary?.status {
                #expect(rem == 0)
            } else {
                #expect(Bool(false), "Expected halved or allSquare(0) status")
            }
        }
    }

    @Test func teamMatchRowsProducedForBothTeams() {
        let (input, a1, a2, b1, b2) = allFourInput(strokes: 4, holes: 1)
        let summary = NetBetterBallEngine.compute(input)
        let rows = NetBetterBallEngine.teamMatchRows(summary: summary, players: input.players)
        #expect(rows.count == 2)
        let ids = Set(rows.map(\.id))
        #expect(ids.contains(.a))
        #expect(ids.contains(.b))
        _ = (a1, a2, b1, b2) // suppress unused warning
    }

    @Test func teamMatchRowsEmptyWhenSummaryNil() {
        let rows = NetBetterBallEngine.teamMatchRows(summary: nil, players: [])
        #expect(rows.isEmpty)
    }

    @Test func finalResultTextFormat() {
        // 3&2 = leading 3 up with 2 remaining.
        // 3-hole course. A wins all 3 — leads 3-0 with 0 remaining → "3 UP" (not early finish).
        // Use 5-hole course: A wins holes 1-3, posted only 3 holes → status depends on remaining.
        let (a1, a2, b1, b2) = makeP2Players()
        let input = makeTeamInput(
            players: [a1, a2, b1, b2],
            scoresPerPlayer: [
                (a1.id, [3, 3, 3]),
                (a2.id, [3, 3, 3]),
                (b1.id, [5, 5, 5]),
                (b2.id, [5, 5, 5])
            ],
            holeCount: 5   // 5 total holes, only 3 posted → 2 remaining after hole 3
        )
        // After hole 3: A leads 3-0, 2 remaining → 3 > 2 → early finish "3&2"
        let summary = NetBetterBallEngine.compute(input)
        if case .won(let winner, let result) = summary?.status {
            #expect(winner == .a)
            #expect(result == "3&2")
        } else {
            #expect(Bool(false), "Expected early finish won status")
        }
    }
}

// MARK: - Handicap differential allocation (reported bug regression suite)

struct HandicapDifferentialAllocationTests {

    // Four-player group matching the reported example.
    // Greg HCP 5, Dave HCP 8, Todd HCP 12, Ralph HCP 18.
    // Min HCP = 5.  Playing handicaps: Greg=0, Dave=3, Todd=7, Ralph=13.
    private let gregHCP  = 5
    private let daveHCP  = 8
    private let toddHCP  = 12
    private let ralphHCP = 18
    private var minHCP: Int { [gregHCP, daveHCP, toddHCP, ralphHCP].min()! }

    // MARK: Playing handicap derivation

    @Test func lowestHandicapPlayerReceivesZeroPlayingHandicap() {
        #expect(max(0, gregHCP - minHCP) == 0)
    }

    @Test func otherPlayersReceiveDifferential() {
        #expect(max(0, daveHCP  - minHCP) == 3)
        #expect(max(0, toddHCP  - minHCP) == 7)
        #expect(max(0, ralphHCP - minHCP) == 13)
    }

    // MARK: Stroke allocation by SI

    // Greg ph=0 → zero strokes on every hole regardless of SI.
    @Test func lowestHandicapPlayerReceivesZeroStrokesOnEveryHole() {
        let ph = max(0, gregHCP - minHCP)   // 0
        for si in 1...18 {
            #expect(HandicapAllocator.strokesReceived(handicap: ph, strokeIndex: si) == 0,
                    "Expected 0 strokes for ph=0 on SI=\(si)")
        }
    }

    // Dave ph=3 → receives 1 stroke on SI 1, 2, 3; zero on SI 4+.
    @Test func daveDifferentialAllocatedByStrokeIndex() {
        let ph = max(0, daveHCP - minHCP)   // 3
        for si in 1...3 {
            #expect(HandicapAllocator.strokesReceived(handicap: ph, strokeIndex: si) == 1,
                    "Dave should receive 1 stroke on SI=\(si)")
        }
        for si in 4...9 {
            #expect(HandicapAllocator.strokesReceived(handicap: ph, strokeIndex: si) == 0,
                    "Dave should receive 0 strokes on SI=\(si)")
        }
    }

    // Todd ph=7 → 1 stroke on SI 1..7, zero on SI 8+.
    @Test func toddDifferentialAllocatedByStrokeIndex() {
        let ph = max(0, toddHCP - minHCP)   // 7
        for si in 1...7 {
            #expect(HandicapAllocator.strokesReceived(handicap: ph, strokeIndex: si) == 1,
                    "Todd should receive 1 stroke on SI=\(si)")
        }
        for si in 8...9 {
            #expect(HandicapAllocator.strokesReceived(handicap: ph, strokeIndex: si) == 0,
                    "Todd should receive 0 strokes on SI=\(si)")
        }
    }

    // Ralph ph=13 → 1 stroke on SI 1..13, zero on SI 14+.
    @Test func ralphDifferentialAllocatedByStrokeIndex() {
        let ph = max(0, ralphHCP - minHCP)  // 13
        for si in 1...13 {
            #expect(HandicapAllocator.strokesReceived(handicap: ph, strokeIndex: si) == 1,
                    "Ralph should receive 1 stroke on SI=\(si)")
        }
        for si in 14...18 {
            #expect(HandicapAllocator.strokesReceived(handicap: ph, strokeIndex: si) == 0,
                    "Ralph should receive 0 strokes on SI=\(si)")
        }
    }

    // MARK: Engine integration — reported example

    /// Full engine run with the exact reported player group.
    /// All post gross 5 on every hole (par-4, 9-hole course, SI=1..9).
    ///
    /// Expected per-hole net scores (gross 5 minus strokes received):
    ///   Holes 1-3  (SI 1-3):  Greg=5, Dave=4, Todd=4, Ralph=4
    ///                          Team A best = min(5,4)=4. Team B best = min(4,4)=4. → Halved
    ///   Holes 4-7  (SI 4-7):  Greg=5, Dave=5, Todd=4, Ralph=4
    ///                          Team A best = min(5,4)=4. Team B best = min(5,4)=4. → Halved
    ///   Holes 8-9  (SI 8-9):  Greg=5, Dave=5, Todd=5, Ralph=4
    ///                          Team A best = min(5,5)=5. Team B best = min(5,4)=4. → B wins
    ///
    /// Final: A=0, B=2, halved=7.  Status: "2 UP" (B wins on last hole, not early finish).
    @Test func reportedExampleMatchResult() {
        let greg  = PlayerCard(id: UUID(), name: "Greg",  handicap: 5,  team: .a)
        let dave  = PlayerCard(id: UUID(), name: "Dave",  handicap: 8,  team: .b)
        let todd  = PlayerCard(id: UUID(), name: "Todd",  handicap: 12, team: .a)
        let ralph = PlayerCard(id: UUID(), name: "Ralph", handicap: 18, team: .b)

        let pars   = Array(repeating: 4, count: 9)
        let si     = Array(1...9)
        let course = CourseLayout(pars: pars, strokeIndices: si)
        var scores: [HoleScore] = []
        for pid in [greg.id, dave.id, todd.id, ralph.id] {
            for h in 1...9 {
                scores.append(HoleScore(playerID: pid, holeNumber: h, strokes: 5))
            }
        }
        let input = RoundInput(
            course: course,
            players: [greg, dave, todd, ralph],
            scores: scores,
            useHandicaps: true,
            gameFormat: .matchPlay
        )

        let summary = NetBetterBallEngine.compute(input)
        #expect(summary?.holesWonA   == 0)
        #expect(summary?.holesWonB   == 2)
        #expect(summary?.holesHalved == 7)

        // Should be "2 UP" — B won on the final hole, not an early finish.
        if case .won(let winner, let result) = summary?.status {
            #expect(winner == .b)
            #expect(result == "2 UP")
        } else {
            #expect(Bool(false), "Expected won status for B")
        }
    }

    /// Verify that "X&Y" early-finish text is only produced when holes remain unplayed,
    /// not when the match closes exactly on the last hole.
    @Test func finalHoleWinProducesXUPNotEarlyFinish() {
        // 3-hole course. A wins holes 1 and 3; B wins hole 2 → tied 1-1 after hole 2.
        // A wins hole 3 (the last hole) → A leads 2-1 with 0 remaining → "2 UP", not "2&0".
        let a1 = PlayerCard(id: UUID(), name: "A1", handicap: 0, team: .a)
        let a2 = PlayerCard(id: UUID(), name: "A2", handicap: 4, team: .a)
        let b1 = PlayerCard(id: UUID(), name: "B1", handicap: 0, team: .b)
        let b2 = PlayerCard(id: UUID(), name: "B2", handicap: 4, team: .b)
        let course = CourseLayout(pars: Array(repeating: 4, count: 3), strokeIndices: Array(1...3))
        // h1: A posts 3, B posts 5 → A wins
        // h2: A posts 5, B posts 3 → B wins
        // h3: A posts 3, B posts 5 → A wins
        var scores: [HoleScore] = []
        let aStrokes = [3, 5, 3]
        let bStrokes = [5, 3, 5]
        for (pid, strokes) in [(a1.id, aStrokes), (a2.id, aStrokes)] {
            for (idx, s) in strokes.enumerated() {
                scores.append(HoleScore(playerID: pid, holeNumber: idx+1, strokes: s))
            }
        }
        for (pid, strokes) in [(b1.id, bStrokes), (b2.id, bStrokes)] {
            for (idx, s) in strokes.enumerated() {
                scores.append(HoleScore(playerID: pid, holeNumber: idx+1, strokes: s))
            }
        }
        let input = RoundInput(course: course, players: [a1, a2, b1, b2],
                               scores: scores, useHandicaps: true, gameFormat: .matchPlay)
        let summary = NetBetterBallEngine.compute(input)

        if case .won(let winner, let result) = summary?.status {
            #expect(winner == .a)
            // A won 2 holes, B won 1 → lead = 1 → "1 UP"
            #expect(result == "1 UP")
            // Must never produce "X&0" (that was the pre-fix bug).
            #expect(!result.hasSuffix("&0"))
        } else {
            #expect(Bool(false), "Expected won status for A")
        }
    }
}

// MARK: - Handicaps ON vs OFF (all 4 combinations)

/// Tests that cover the four supported scoring combinations:
///   1. Stroke Play + Handicaps ON
///   2. Stroke Play + Handicaps OFF
///   3. Match Play + Handicaps ON
///   4. Match Play + Handicaps OFF
struct HandicapToggleTests {

    // MARK: - Shared fixtures

    /// 3-hole course, all par 4, SI = 1,2,3.
    private let course = CourseLayout(pars: [4, 4, 4], strokeIndices: [1, 2, 3])

    /// Player A: HCP 3 (receives strokes on SI 1, 2, 3)
    private let playerA = PlayerCard(id: UUID(), name: "Alpha", handicap: 3)
    /// Player B: HCP 0 (receives no strokes)
    private let playerB = PlayerCard(id: UUID(), name: "Beta",  handicap: 0)

    /// Both players post 5 on every hole (one over par on a par-4).
    private func makeScores(playerID: UUID, strokes: Int, holes: Int) -> [HoleScore] {
        (1...holes).map { HoleScore(playerID: playerID, holeNumber: $0, strokes: strokes) }
    }

    // MARK: - 1. Stroke Play + Handicaps ON

    @Test func strokePlayHandicapsOn_netDeltaReflectsStrokesReceived() {
        let scores = makeScores(playerID: playerA.id, strokes: 5, holes: 3)
            + makeScores(playerID: playerB.id, strokes: 5, holes: 3)
        let input = RoundInput(course: course, players: [playerA, playerB],
                               scores: scores, useHandicaps: true, gameFormat: .strokePlay)

        // Alpha receives 3 strokes total (1 per hole, SI 1-3). Gross 15, Net 12. GrossPar 12.
        // netDelta = netTotal - grossPar = 12 - 12 = 0 (par is fixed; strokes received don't reduce it).
        let rowA = StrokePlayEngine.buildRow(for: playerA, through: 3, input: input)
        #expect(rowA.grossTotal == 15)
        #expect(rowA.netTotal   == 12)
        #expect(rowA.grossDelta == 3)   // 15 - 12
        #expect(rowA.netDelta   == 0)   // 12 - 12 (net total vs unadjusted course par)

        // Beta: HCP 0, no strokes received. Net == Gross.
        let rowB = StrokePlayEngine.buildRow(for: playerB, through: 3, input: input)
        #expect(rowB.grossTotal == 15)
        #expect(rowB.netTotal   == 15)
        #expect(rowB.grossDelta == 3)
        #expect(rowB.netDelta   == 3)
    }

    // MARK: - 2. Stroke Play + Handicaps OFF

    @Test func strokePlayHandicapsOff_netEqualsGrossForAllPlayers() {
        let scores = makeScores(playerID: playerA.id, strokes: 5, holes: 3)
            + makeScores(playerID: playerB.id, strokes: 5, holes: 3)
        let input = RoundInput(course: course, players: [playerA, playerB],
                               scores: scores, useHandicaps: false, gameFormat: .strokePlay)

        // With handicaps OFF, Alpha's HCP 3 should be completely ignored.
        let rowA = StrokePlayEngine.buildRow(for: playerA, through: 3, input: input)
        #expect(rowA.netTotal == rowA.grossTotal, "Net must equal gross when handicaps are off")
        #expect(rowA.netDelta == rowA.grossDelta, "Net delta must equal gross delta when handicaps are off")

        let rowB = StrokePlayEngine.buildRow(for: playerB, through: 3, input: input)
        #expect(rowB.netTotal == rowB.grossTotal)
        #expect(rowB.netDelta == rowB.grossDelta)
    }

    @Test func strokePlayHandicapsOff_holeResultReceivedIsZero() {
        let pcA = PlayerCard(id: UUID(), name: "Alpha", handicap: 18)
        let result = StrokePlayEngine.holeResult(
            for: pcA, hole: 1, strokes: 5,
            course: course, useHandicaps: false
        )
        #expect(result.received == 0, "No strokes received when handicaps are off")
        #expect(result.netStrokes == result.grossStrokes)
    }

    // MARK: - 3. Match Play + Handicaps ON

    @Test func matchPlayHandicapsOn_winnerDeterminedByNetScores() {
        // 3-hole, all par 4.
        // Team A: a1(HCP 0), a2(HCP 0). Team B: b1(HCP 3), b2(HCP 0).
        // Min HCP = 0. b1 playing HCP = 3, receives 1 stroke on SI 1, 2, 3.
        // All players post gross 5 on every hole.
        // Net scores: a1=5, a2=5, b1=4 (5-1), b2=5.
        // Team A best = 5, Team B best = 4. B wins all 3 holes → B wins "3 UP".
        let a1 = PlayerCard(id: UUID(), name: "A1", handicap: 0, team: .a)
        let a2 = PlayerCard(id: UUID(), name: "A2", handicap: 0, team: .a)
        let b1 = PlayerCard(id: UUID(), name: "B1", handicap: 3, team: .b)
        let b2 = PlayerCard(id: UUID(), name: "B2", handicap: 0, team: .b)

        var scores: [HoleScore] = []
        for pid in [a1.id, a2.id, b1.id, b2.id] {
            for h in 1...3 { scores.append(HoleScore(playerID: pid, holeNumber: h, strokes: 5)) }
        }
        let input = RoundInput(course: course, players: [a1, a2, b1, b2],
                               scores: scores, useHandicaps: true, gameFormat: .matchPlay)
        let summary = NetBetterBallEngine.compute(input)

        #expect(summary?.holesWonB == 3)
        #expect(summary?.holesWonA == 0)
        if case .won(let winner, _) = summary?.status {
            #expect(winner == .b, "Team B should win with net-better-ball advantage")
        } else {
            #expect(Bool(false), "Expected won status")
        }
    }

    // MARK: - 4. Match Play + Handicaps OFF

    @Test func matchPlayHandicapsOff_winnerDeterminedByGrossScores() {
        // Same setup as the ON test above, but handicaps OFF.
        // All players post gross 5. No strokes received by anyone.
        // Team A best = 5, Team B best = 5. Every hole is halved → AS / Halved.
        let a1 = PlayerCard(id: UUID(), name: "A1", handicap: 0, team: .a)
        let a2 = PlayerCard(id: UUID(), name: "A2", handicap: 0, team: .a)
        let b1 = PlayerCard(id: UUID(), name: "B1", handicap: 3, team: .b) // HCP 3 should be ignored
        let b2 = PlayerCard(id: UUID(), name: "B2", handicap: 0, team: .b)

        var scores: [HoleScore] = []
        for pid in [a1.id, a2.id, b1.id, b2.id] {
            for h in 1...3 { scores.append(HoleScore(playerID: pid, holeNumber: h, strokes: 5)) }
        }
        let input = RoundInput(course: course, players: [a1, a2, b1, b2],
                               scores: scores, useHandicaps: false, gameFormat: .matchPlay)
        let summary = NetBetterBallEngine.compute(input)

        // All holes halved because gross scores are equal and handicaps are ignored.
        #expect(summary?.holesHalved == 3, "All holes should halve when handicaps are off and scores are equal")
        #expect(summary?.holesWonA == 0)
        #expect(summary?.holesWonB == 0)
        if case .halved = summary?.status {
            // correct
        } else {
            #expect(Bool(false), "Expected halved match when handicaps off and equal gross scores")
        }
    }

    @Test func matchPlayHandicapsOff_grossAdvantageWins() {
        // Handicaps OFF. A posts 4 on every hole, B posts 5. A should win all 3 holes gross.
        let a1 = PlayerCard(id: UUID(), name: "A1", handicap: 5, team: .a)  // high HCP, ignored
        let a2 = PlayerCard(id: UUID(), name: "A2", handicap: 5, team: .a)
        let b1 = PlayerCard(id: UUID(), name: "B1", handicap: 0, team: .b)
        let b2 = PlayerCard(id: UUID(), name: "B2", handicap: 0, team: .b)

        var scores: [HoleScore] = []
        for pid in [a1.id, a2.id] {
            for h in 1...3 { scores.append(HoleScore(playerID: pid, holeNumber: h, strokes: 4)) }
        }
        for pid in [b1.id, b2.id] {
            for h in 1...3 { scores.append(HoleScore(playerID: pid, holeNumber: h, strokes: 5)) }
        }
        let input = RoundInput(course: course, players: [a1, a2, b1, b2],
                               scores: scores, useHandicaps: false, gameFormat: .matchPlay)
        let summary = NetBetterBallEngine.compute(input)

        #expect(summary?.holesWonA == 3, "A should win all 3 holes on gross score")
        #expect(summary?.holesWonB == 0)
        if case .won(let winner, _) = summary?.status {
            #expect(winner == .a)
        } else {
            #expect(Bool(false), "Expected A to win")
        }
    }

    @Test func matchPlayHandicapsOn_vs_Off_differentOutcome() {
        // This test confirms the toggle actually changes the match result.
        // b1 has HCP 3. All post gross 5. With HCP ON, b1 nets 4 on SI 1-3 → B wins.
        // With HCP OFF, everyone nets 5 (gross) → halved.
        let a1 = PlayerCard(id: UUID(), name: "A1", handicap: 0, team: .a)
        let a2 = PlayerCard(id: UUID(), name: "A2", handicap: 0, team: .a)
        let b1 = PlayerCard(id: UUID(), name: "B1", handicap: 3, team: .b)
        let b2 = PlayerCard(id: UUID(), name: "B2", handicap: 0, team: .b)
        let players = [a1, a2, b1, b2]

        var scores: [HoleScore] = []
        for pid in players.map(\.id) {
            for h in 1...3 { scores.append(HoleScore(playerID: pid, holeNumber: h, strokes: 5)) }
        }

        let inputOn  = RoundInput(course: course, players: players, scores: scores,
                                  useHandicaps: true,  gameFormat: .matchPlay)
        let inputOff = RoundInput(course: course, players: players, scores: scores,
                                  useHandicaps: false, gameFormat: .matchPlay)

        let summaryOn  = NetBetterBallEngine.compute(inputOn)
        let summaryOff = NetBetterBallEngine.compute(inputOff)

        // ON: B wins (net advantage from HCP 3)
        if case .won(let winner, _) = summaryOn?.status {
            #expect(winner == .b)
        } else {
            #expect(Bool(false), "HCP ON: expected B to win")
        }

        // OFF: all halved (gross tie)
        if case .halved = summaryOff?.status {
            // correct
        } else {
            #expect(Bool(false), "HCP OFF: expected halved match")
        }
    }
}

// MARK: - Stroke Play Status Strip margin logic

/// Tests that validate the running-total comparison used by strokePlayStatusStrip.
///
/// The strip computes:
///   leaderTotal  = sortedRows.first!.net/grossTotal
///   secondTotal  = sortedRows.dropFirst().first!.net/grossTotal
///   margin       = secondTotal - leaderTotal
///
/// These tests confirm the domain output that the strip must be derived from.
struct StrokePlayStripTests {

    // 3 holes, par 4 each, SI 1/2/3
    private let course = CourseLayout(pars: [4, 4, 4], strokeIndices: [1, 2, 3])

    // MARK: - Handicaps ON

    /// Greg (HCP 0) posts 4,4,4 → gross 12, net 12, delta 0.
    /// Todd (HCP 3) posts 5,5,5 → gross 15, net 12 (receives 1 stroke each hole), delta 0.
    @Test func handicapsOn_tiedTotals() {
        let greg = PlayerCard(id: UUID(), name: "Greg", handicap: 0)
        let todd = PlayerCard(id: UUID(), name: "Todd", handicap: 3)

        var scores: [HoleScore] = []
        for h in 1...3 { scores.append(HoleScore(playerID: greg.id, holeNumber: h, strokes: 4)) }
        for h in 1...3 { scores.append(HoleScore(playerID: todd.id, holeNumber: h, strokes: 5)) }

        let input = RoundInput(course: course, players: [greg, todd],
                               scores: scores, useHandicaps: true, gameFormat: .strokePlay)
        let rows = StrokePlayEngine.buildRows(for: input, through: 3)

        let sorted = rows.sorted {
            if $0.netTotal != $1.netTotal { return $0.netTotal < $1.netTotal }
            return $0.name < $1.name
        }

        let leader = sorted[0]
        let second = sorted[1]

        // Both net 12 — tied; names sort alphabetically so Greg leads, Todd second
        #expect(leader.netTotal == 12)
        #expect(second.netTotal == 12)
        // Margin is zero → tied
        #expect(second.netTotal - leader.netTotal == 0)
    }

    /// Greg (HCP 0) posts 4,4,4 → net 12.
    /// Todd (HCP 3) posts 6,6,6 → gross 18, net 15 (3 strokes received).
    /// Lead margin = 15 - 12 = 3.
    @Test func handicapsOn_leaderMarginFromNetTotals() {
        let greg = PlayerCard(id: UUID(), name: "Greg", handicap: 0)
        let todd = PlayerCard(id: UUID(), name: "Todd", handicap: 3)

        var scores: [HoleScore] = []
        for h in 1...3 { scores.append(HoleScore(playerID: greg.id, holeNumber: h, strokes: 4)) }
        for h in 1...3 { scores.append(HoleScore(playerID: todd.id, holeNumber: h, strokes: 6)) }

        let input = RoundInput(course: course, players: [greg, todd],
                               scores: scores, useHandicaps: true, gameFormat: .strokePlay)
        let rows = StrokePlayEngine.buildRows(for: input, through: 3)

        let sorted = rows.sorted {
            if $0.netTotal != $1.netTotal { return $0.netTotal < $1.netTotal }
            return $0.name < $1.name
        }

        let leaderTotal = sorted[0].netTotal
        let secondTotal = sorted[1].netTotal

        #expect(leaderTotal == 12, "Greg net total should be 12")
        #expect(secondTotal == 15, "Todd net total should be 15 (gross 18 - 3 received)")
        #expect(secondTotal - leaderTotal == 3, "Margin should be 3 strokes (net totals)")
    }

    // MARK: - Handicaps OFF

    /// Greg posts 4,4,4 → gross 12. Todd posts 5,5,5 → gross 15.
    /// Margin from gross totals = 15 - 12 = 3.
    @Test func handicapsOff_leaderMarginFromGrossTotals() {
        let greg = PlayerCard(id: UUID(), name: "Greg", handicap: 0)
        let todd = PlayerCard(id: UUID(), name: "Todd", handicap: 18)  // HCP ignored

        var scores: [HoleScore] = []
        for h in 1...3 { scores.append(HoleScore(playerID: greg.id, holeNumber: h, strokes: 4)) }
        for h in 1...3 { scores.append(HoleScore(playerID: todd.id, holeNumber: h, strokes: 5)) }

        let input = RoundInput(course: course, players: [greg, todd],
                               scores: scores, useHandicaps: false, gameFormat: .strokePlay)
        let rows = StrokePlayEngine.buildRows(for: input, through: 3)

        let sorted = rows.sorted {
            if $0.grossTotal != $1.grossTotal { return $0.grossTotal < $1.grossTotal }
            return $0.name < $1.name
        }

        let leaderTotal = sorted[0].grossTotal
        let secondTotal = sorted[1].grossTotal

        #expect(leaderTotal == 12, "Greg gross total should be 12")
        #expect(secondTotal == 15, "Todd gross total should be 15 (HCP ignored)")
        #expect(secondTotal - leaderTotal == 3, "Margin should be 3 strokes (gross totals)")
    }

    /// Replicates the reported bug scenario: Greg 54, Todd 68, handicaps ON.
    /// Correct margin = 68 - 54 = 14 (not 3, which was the buggy delta difference).
    @Test func handicapsOn_largeMarginMatchesLeaderboard() {
        // 18-hole course, all par 4, SI 1..18
        let pars18 = Array(repeating: 4, count: 18)
        let sis18  = Array(1...18)
        let course18 = CourseLayout(pars: pars18, strokeIndices: sis18)

        let greg = PlayerCard(id: UUID(), name: "Greg", handicap: 0)
        let todd = PlayerCard(id: UUID(), name: "Todd", handicap: 0)

        // Greg posts 3 strokes per hole → gross 54 (net 54, HCP 0)
        // Todd posts 4 per hole through 15, then 5 on holes 16–18:
        // 15×4 + 3×5 = 60 + 15 = 75... adjusted to reach 68: posts 3 on 10 holes, 4 on 8 holes
        // Simpler: Greg = 54 (3 each), Todd = 68 (mix to sum 68)
        // 14 holes × 4 = 56, 4 holes × 3 = 12 → 68. Use 4 holes of 3, 14 holes of 4.
        var scores: [HoleScore] = []
        for h in 1...18 { scores.append(HoleScore(playerID: greg.id, holeNumber: h, strokes: 3)) }
        // Todd: holes 1-4 score 3, holes 5-18 score 4+: 4×3 + 14×(68-12)/14 = need exact
        // 4×3 = 12, remaining 14 holes must sum to 68-12=56, so 56/14 = 4 each. ✓
        for h in 1...4  { scores.append(HoleScore(playerID: todd.id, holeNumber: h, strokes: 3)) }
        for h in 5...18 { scores.append(HoleScore(playerID: todd.id, holeNumber: h, strokes: 4)) }

        let input = RoundInput(course: course18, players: [greg, todd],
                               scores: scores, useHandicaps: true, gameFormat: .strokePlay)
        let rows = StrokePlayEngine.buildRows(for: input, through: 18)

        let sorted = rows.sorted {
            if $0.netTotal != $1.netTotal { return $0.netTotal < $1.netTotal }
            return $0.name < $1.name
        }

        let leaderTotal = sorted[0].netTotal  // Greg: 54
        let secondTotal = sorted[1].netTotal  // Todd: 68
        let margin = secondTotal - leaderTotal

        #expect(leaderTotal == 54)
        #expect(secondTotal == 68)
        #expect(margin == 14, "Margin must be 14 (total-based), not 3 (delta-based)")
    }
}

// MARK: - SkinsEngineTests

@Suite("SkinsEngine")
struct SkinsEngineTests {

    // 3-hole course, par 4 each, SI 1/2/3
    private let course = CourseLayout(pars: [4, 4, 4], strokeIndices: [1, 2, 3])

    // Convenience: build a 2-player RoundInput with supplied per-hole stroke arrays
    private func input(
        _ aScores: [Int],
        _ bScores: [Int],
        players aPlayer: PlayerCard? = nil,
        _ bPlayer: PlayerCard? = nil
    ) -> (RoundInput, PlayerCard, PlayerCard) {
        let a = aPlayer ?? PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = bPlayer ?? PlayerCard(id: UUID(), name: "Bob",   handicap: 0)
        var scores: [HoleScore] = []
        for (i, s) in aScores.enumerated() {
            scores.append(HoleScore(playerID: a.id, holeNumber: i + 1, strokes: s))
        }
        for (i, s) in bScores.enumerated() {
            scores.append(HoleScore(playerID: b.id, holeNumber: i + 1, strokes: s))
        }
        let ri = RoundInput(course: course, players: [a, b],
                            scores: scores, useHandicaps: false, gameFormat: .skins)
        return (ri, a, b)
    }

    // MARK: - Null / edge cases

    /// Returns nil when there are no players.
    @Test func noPlayers_returnsNil() {
        let ri = RoundInput(course: course, players: [],
                            scores: [], useHandicaps: false, gameFormat: .skins)
        #expect(SkinsEngine.compute(ri) == nil)
    }

    /// Returns nil when no scores have been posted.
    @Test func noScores_returnsNil() {
        let (ri, _, _) = input([], [])
        #expect(SkinsEngine.compute(ri) == nil)
    }

    /// thruHole stops at first gap — partial first hole isn't counted.
    @Test func partialHoleOne_returnsNil() {
        // Only Alice posted hole 1; Bob hasn't.
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 0)
        let scores = [HoleScore(playerID: a.id, holeNumber: 1, strokes: 4)]
        let ri = RoundInput(course: course, players: [a, b],
                            scores: scores, useHandicaps: false, gameFormat: .skins)
        #expect(SkinsEngine.compute(ri) == nil)
    }

    // MARK: - Outright winner

    /// Alice wins hole 1 outright, collects 1 skin. No carry.
    @Test func outright_winner_hole1() {
        let (ri, a, _) = input([3, 4, 4], [4, 4, 4])
        let summary = SkinsEngine.compute(ri)!

        #expect(summary.thruHole == 3)
        #expect(summary.pendingCarry == 0)
        #expect(summary.skinsPerPlayer[a.id] == 1)
    }

    /// Bob wins all three holes, collects 3 skins total.
    @Test func outright_winner_all_holes() {
        let (ri, _, b) = input([5, 5, 5], [4, 4, 4])
        let summary = SkinsEngine.compute(ri)!

        #expect(summary.skinsPerPlayer[b.id] == 3)
        #expect(summary.pendingCarry == 0)
    }

    // MARK: - Carry logic

    /// Hole 1 tied → carry 1. Alice wins hole 2 → collects 2 skins.
    @Test func carry_resolves_on_hole2() {
        // Hole 1: 4-4 (tie → carry). Hole 2: Alice 3, Bob 4 (Alice wins 2 skins).
        let (ri, a, _) = input([4, 3, 4], [4, 4, 4])
        let summary = SkinsEngine.compute(ri)!

        #expect(summary.skinsPerPlayer[a.id] == 2)
        #expect(summary.pendingCarry == 0)

        // Hole 1 outcome: no winner, carryOut = 1.
        let h1 = summary.holeOutcomes[0]
        #expect(h1.winner == nil)
        #expect(h1.carryOut == 1)

        // Hole 2 outcome: Alice wins 2 skins, carry resets.
        let h2 = summary.holeOutcomes[1]
        #expect(h2.winner == a.id)
        #expect(h2.skinsWon == 2)
        #expect(h2.carryOut == 0)
    }

    /// Holes 1 and 2 both tied → carry 2. Bob wins hole 3 → collects 3 skins.
    @Test func double_carry_resolves_on_hole3() {
        // H1: 4-4 tie. H2: 4-4 tie. H3: Alice 5, Bob 4 (Bob wins 3 skins).
        let (ri, _, b) = input([4, 4, 5], [4, 4, 4])
        let summary = SkinsEngine.compute(ri)!

        #expect(summary.skinsPerPlayer[b.id] == 3)
        #expect(summary.pendingCarry == 0)

        let h3 = summary.holeOutcomes[2]
        #expect(h3.winner == b.id)
        #expect(h3.skinsWon == 3)
    }

    /// All three holes tied → carry stays 3, pendingCarry == 3 at end.
    @Test func all_tied_pendingCarry() {
        let (ri, a, b) = input([4, 4, 4], [4, 4, 4])
        let summary = SkinsEngine.compute(ri)!

        #expect(summary.pendingCarry == 3)
        #expect(summary.skinsPerPlayer[a.id] == nil)
        #expect(summary.skinsPerPlayer[b.id] == nil)
    }

    // MARK: - thruHole gap handling

    /// Scores posted for holes 1 & 2 only — thruHole == 2.
    @Test func thruHole_stops_at_last_complete() {
        let (ri, a, _) = input([3, 4], [4, 4])   // only 2 of 3 holes posted
        let summary = SkinsEngine.compute(ri)!

        #expect(summary.thruHole == 2)
        #expect(summary.holeOutcomes.count == 2)
        #expect(summary.skinsPerPlayer[a.id] == 1)
    }

    // MARK: - skinsRows sorting

    /// Leader row appears first, zero-skins player last.
    @Test func skinsRows_sortedBySkinsDescThenName() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 0)
        let c = PlayerCard(id: UUID(), name: "Carol", handicap: 0)

        // Alice wins 2, Bob wins 1, Carol wins 0.
        let summary = SkinsSummary(
            holeOutcomes: [],
            skinsPerPlayer: [a.id: 2, b.id: 1],
            pendingCarry: 0,
            thruHole: 3
        )
        let rows = SkinsEngine.skinsRows(summary: summary, players: [c, b, a])

        #expect(rows[0].id == a.id)
        #expect(rows[1].id == b.id)
        #expect(rows[2].id == c.id)
    }

    /// Alphabetical tiebreak when skins counts match.
    @Test func skinsRows_alphabeticalTiebreak() {
        let a = PlayerCard(id: UUID(), name: "Zara",  handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Aaron", handicap: 0)

        // Both have 1 skin.
        let summary = SkinsSummary(
            holeOutcomes: [],
            skinsPerPlayer: [a.id: 1, b.id: 1],
            pendingCarry: 0,
            thruHole: 1
        )
        let rows = SkinsEngine.skinsRows(summary: summary, players: [a, b])

        // Aaron < Zara alphabetically.
        #expect(rows[0].name == "Aaron")
        #expect(rows[1].name == "Zara")
    }

    /// skinsRows with nil summary returns all players with 0 skins.
    @Test func skinsRows_nilSummary_allZero() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 0)

        let rows = SkinsEngine.skinsRows(summary: nil, players: [a, b])
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.skinsWon == 0 })
    }
}

// MARK: - SkinsStripLogicTests
//
// These tests validate the primary-line logic used by skinsStatusStrip in LiveRoundView.
// The strip derives leaders as: rows.filter { $0.skinsWon == maxSkins }, maxSkins > 0.
// Tests confirm the strip and LeaderboardView always agree — both consume skinsRows().

@Suite("SkinsStripLogic")
struct SkinsStripLogicTests {

    private let course = CourseLayout(pars: [4, 4, 4], strokeIndices: [1, 2, 3])

    // Helper: simulate the strip's primary-line derivation from a RoundInput.
    private func primaryLine(for input: RoundInput) -> String {
        let summary = SkinsEngine.compute(input)
        let rows = SkinsEngine.skinsRows(summary: summary, players: input.players)
        let maxSkins = rows.first?.skinsWon ?? 0
        let leaders = maxSkins > 0 ? rows.filter { $0.skinsWon == maxSkins } : []

        guard !leaders.isEmpty else { return "No skins won yet" }
        let names = leaders
            .map { $0.name.components(separatedBy: " ").first ?? $0.name }
            .joined(separator: ", ")
        return "\(names) • Skins \(maxSkins)"
    }

    // Helper: same input, leaderboard max skins value.
    private func leaderboardMaxSkins(for input: RoundInput) -> Int {
        let summary = SkinsEngine.compute(input)
        let rows = SkinsEngine.skinsRows(summary: summary, players: input.players)
        return rows.first?.skinsWon ?? 0
    }

    // MARK: - No skins won yet

    /// All holes tied → nobody has won a skin → "No skins won yet"
    @Test func primaryLine_noSkinsWon_allTied() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 0)
        var scores: [HoleScore] = []
        for h in 1...3 { scores.append(HoleScore(playerID: a.id, holeNumber: h, strokes: 4)) }
        for h in 1...3 { scores.append(HoleScore(playerID: b.id, holeNumber: h, strokes: 4)) }
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: false, gameFormat: .skins)

        #expect(primaryLine(for: input) == "No skins won yet")
        // Leaderboard also shows 0 for both
        #expect(leaderboardMaxSkins(for: input) == 0)
    }

    /// Carry accumulating after holes 1–2 both tied, hole 3 not yet posted.
    @Test func primaryLine_noSkinsWon_carryBuilding() {
        let a = PlayerCard(id: UUID(), name: "Carol", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Dave",  handicap: 0)
        // Post holes 1 and 2 tied; hole 3 not posted
        var scores: [HoleScore] = []
        for h in 1...2 { scores.append(HoleScore(playerID: a.id, holeNumber: h, strokes: 4)) }
        for h in 1...2 { scores.append(HoleScore(playerID: b.id, holeNumber: h, strokes: 4)) }
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: false, gameFormat: .skins)

        let summary = SkinsEngine.compute(input)!
        #expect(summary.pendingCarry == 2)
        #expect(primaryLine(for: input) == "No skins won yet")
    }

    // MARK: - Single leader

    /// Alice wins hole 1 outright → "Alice • Skins 1"
    @Test func primaryLine_singleLeader() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 0)
        var scores: [HoleScore] = []
        scores.append(HoleScore(playerID: a.id, holeNumber: 1, strokes: 3))
        scores.append(HoleScore(playerID: b.id, holeNumber: 1, strokes: 4))
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: false, gameFormat: .skins)

        #expect(primaryLine(for: input) == "Alice • Skins 1")
        // Strip value matches leaderboard value
        let rows = SkinsEngine.skinsRows(summary: SkinsEngine.compute(input), players: [a, b])
        #expect(rows.first(where: { $0.name == "Alice" })?.skinsWon == 1)
    }

    /// Bob wins 2 skins (carry resolved) → "Bob • Skins 2"
    @Test func primaryLine_singleLeader_withCarry() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 0)
        // H1 tie → carry. H2 Bob wins → collects 2.
        var scores: [HoleScore] = []
        scores.append(HoleScore(playerID: a.id, holeNumber: 1, strokes: 4))
        scores.append(HoleScore(playerID: b.id, holeNumber: 1, strokes: 4))
        scores.append(HoleScore(playerID: a.id, holeNumber: 2, strokes: 5))
        scores.append(HoleScore(playerID: b.id, holeNumber: 2, strokes: 4))
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: false, gameFormat: .skins)

        #expect(primaryLine(for: input) == "Bob • Skins 2")
        #expect(leaderboardMaxSkins(for: input) == 2)
    }

    // MARK: - Tied leaders

    /// Alice wins H1, Bob wins H2 → both have 1 skin → "Alice, Bob • Skins 1"
    @Test func primaryLine_tiedLeaders_twoPlayers() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 0)
        // H1: Alice 3, Bob 4. H2: Alice 5, Bob 4.
        var scores: [HoleScore] = []
        scores.append(HoleScore(playerID: a.id, holeNumber: 1, strokes: 3))
        scores.append(HoleScore(playerID: b.id, holeNumber: 1, strokes: 4))
        scores.append(HoleScore(playerID: a.id, holeNumber: 2, strokes: 5))
        scores.append(HoleScore(playerID: b.id, holeNumber: 2, strokes: 4))
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: false, gameFormat: .skins)

        #expect(primaryLine(for: input) == "Alice, Bob • Skins 1")
        // Both leaders on leaderboard also show 1
        let rows = SkinsEngine.skinsRows(summary: SkinsEngine.compute(input), players: [a, b])
        let topSkins = rows.first?.skinsWon ?? 0
        let tiedCount = rows.filter { $0.skinsWon == topSkins }.count
        #expect(topSkins == 1)
        #expect(tiedCount == 2)
    }

    /// Three-way tie — all three win 1 skin → names listed alphabetically.
    @Test func primaryLine_tiedLeaders_threePlayers() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 0)
        let c = PlayerCard(id: UUID(), name: "Carol", handicap: 0)
        // Use a 3-hole course. Each player wins one hole outright.
        // H1: Alice 3, Bob 4, Carol 4. H2: Alice 4, Bob 3, Carol 4. H3: Alice 4, Bob 4, Carol 3.
        var scores: [HoleScore] = []
        let holeScores: [(Int, Int, Int)] = [(3,4,4),(4,3,4),(4,4,3)]
        for (h, (sa, sb, sc)) in holeScores.enumerated() {
            scores.append(HoleScore(playerID: a.id, holeNumber: h+1, strokes: sa))
            scores.append(HoleScore(playerID: b.id, holeNumber: h+1, strokes: sb))
            scores.append(HoleScore(playerID: c.id, holeNumber: h+1, strokes: sc))
        }
        let input = RoundInput(course: course, players: [a, b, c],
                               scores: scores, useHandicaps: false, gameFormat: .skins)

        #expect(primaryLine(for: input) == "Alice, Bob, Carol • Skins 1")
        #expect(leaderboardMaxSkins(for: input) == 1)
    }

    // MARK: - Strip == Leaderboard

    /// The max skins value shown by the strip always equals the leaderboard's top row value.
    @Test func stripMaxAlwaysMatchesLeaderboard() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 0)
        // Alice wins all 3 holes
        var scores: [HoleScore] = []
        for h in 1...3 { scores.append(HoleScore(playerID: a.id, holeNumber: h, strokes: 3)) }
        for h in 1...3 { scores.append(HoleScore(playerID: b.id, holeNumber: h, strokes: 4)) }
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: false, gameFormat: .skins)

        let summary = SkinsEngine.compute(input)!
        let rows = SkinsEngine.skinsRows(summary: summary, players: [a, b])
        let leaderboardTop = rows.first?.skinsWon ?? 0

        // Strip derives the same value
        let maxSkins = rows.first?.skinsWon ?? 0
        #expect(maxSkins == leaderboardTop)
        #expect(primaryLine(for: input) == "Alice • Skins 3")
    }
}

// MARK: - SkinsHandicapTests
//
// Prove that SkinsEngine respects useHandicaps when determining hole winners.
// These tests describe the REQUIRED behaviour; they will fail against the pre-fix
// engine (which always uses gross scores) and must pass after the fix.

@Suite("SkinsHandicap")
struct SkinsHandicapTests {

    // 3-hole course: par 4,4,4 — SI 1,2,3
    private let course = CourseLayout(pars: [4, 4, 4], strokeIndices: [1, 2, 3])

    // MARK: - Gross skins (handicaps OFF)

    /// Handicaps OFF: gross scores decide the winner.
    /// Alice 3, Bob 5 on hole 1 → Alice wins gross.
    @Test func gross_handicapsOff_grossWinner() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 9)  // HCP ignored
        let scores = [
            HoleScore(playerID: a.id, holeNumber: 1, strokes: 3),
            HoleScore(playerID: b.id, holeNumber: 1, strokes: 5),
        ]
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: false, gameFormat: .skins)
        let summary = SkinsEngine.compute(input)!

        // Alice wins gross outright — 1 skin
        #expect(summary.skinsPerPlayer[a.id] == 1)
        #expect(summary.skinsPerPlayer[b.id] == nil)
    }

    /// Handicaps OFF: tied gross → carry.
    /// Alice 4, Bob 4 → nobody wins, carry 1.
    @Test func gross_handicapsOff_tiedGrossCarries() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 9)
        let scores = [
            HoleScore(playerID: a.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: b.id, holeNumber: 1, strokes: 4),
        ]
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: false, gameFormat: .skins)
        let summary = SkinsEngine.compute(input)!

        #expect(summary.pendingCarry == 1)
        #expect(summary.skinsPerPlayer.isEmpty)
    }

    // MARK: - Net skins (handicaps ON)

    /// Handicaps ON: net scores decide the winner.
    ///
    /// Course SI 1 on hole 1.
    /// Alice: HCP 0, gross 4, receives 0 strokes → net 4
    /// Bob:   HCP 9, gross 5, receives 1 stroke (SI 1 ≤ 9) → net 4
    ///
    /// Net tie → carry 1. (Gross winner would be Alice, but net is tied.)
    @Test func net_handicapsOn_netTieOverridesGrossWinner() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 9)
        // Hole 1, SI 1: Bob receives 1 stroke (9 >= 1).  Net Bob = 5-1 = 4.  Net Alice = 4.
        let scores = [
            HoleScore(playerID: a.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: b.id, holeNumber: 1, strokes: 5),
        ]
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: true, gameFormat: .skins)
        let summary = SkinsEngine.compute(input)!

        // Net is tied (both 4) → carry, not Alice winning
        #expect(summary.pendingCarry == 1, "Net tie must carry, not award to gross leader")
        #expect(summary.skinsPerPlayer.isEmpty, "Nobody should win when net scores are tied")
    }

    /// Handicaps ON: net winner differs from gross winner.
    ///
    /// Alice: HCP 0, gross 3 → net 3 (no stroke on SI 1)
    /// Bob:   HCP 18, gross 4, receives 1 stroke (SI 1 ≤ 18) → net 3
    ///
    /// Net tie → carry. Gross winner would be Alice (3 vs 4), but net is 3 vs 3.
    @Test func net_handicapsOn_netTie_grossDiffers() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 18)
        // Hole 1, SI 1: Bob receives 1 stroke. Net Bob = 4-1 = 3.  Net Alice = 3.
        let scores = [
            HoleScore(playerID: a.id, holeNumber: 1, strokes: 3),
            HoleScore(playerID: b.id, holeNumber: 1, strokes: 4),
        ]
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: true, gameFormat: .skins)
        let summary = SkinsEngine.compute(input)!

        #expect(summary.pendingCarry == 1, "Net tie must carry even when gross differs")
        #expect(summary.skinsPerPlayer.isEmpty)
    }

    /// Handicaps ON: outright net winner is correctly identified.
    ///
    /// Alice: HCP 0, gross 3 → net 3
    /// Bob:   HCP 9, gross 4, SI 1 → receives 1 stroke → net 3
    ///
    /// Both net 3 on hole 1 (carry).
    ///
    /// Hole 2 (SI 2, Bob HCP 9 ≥ 2 → receives 1):
    /// Alice: gross 5 → net 5
    /// Bob:   gross 5 → net 4
    /// Net winner: Bob (4 < 5). Bob collects 2 skins.
    @Test func net_handicapsOn_outrightNetWinner() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 9)
        // Hole 1: SI 1 — Bob receives 1. Net Alice=3, Net Bob=4-1=3. Tied → carry 1.
        // Hole 2: SI 2 — Bob receives 1. Net Alice=5, Net Bob=5-1=4. Bob wins 2 skins.
        let scores = [
            HoleScore(playerID: a.id, holeNumber: 1, strokes: 3),
            HoleScore(playerID: b.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: a.id, holeNumber: 2, strokes: 5),
            HoleScore(playerID: b.id, holeNumber: 2, strokes: 5),
        ]
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: true, gameFormat: .skins)
        let summary = SkinsEngine.compute(input)!

        #expect(summary.skinsPerPlayer[b.id] == 2, "Bob must win 2 skins (carry resolved on hole 2 via net)")
        #expect(summary.skinsPerPlayer[a.id] == nil)
        #expect(summary.pendingCarry == 0)
    }

    /// Handicaps ON: tied net on hole 2 after a carry → carry continues.
    ///
    /// Hole 1: gross tie → carry 1.
    /// Hole 2 (SI 2): Alice gross 4 net 4, Bob gross 5 HCP 9 → net 4. Net tie → carry 2.
    @Test func net_handicapsOn_carryAccumulates() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 9)
        // Hole 1 SI 1: net Alice=4, net Bob=4-1=3... wait — Bob HCP 9, SI 1 → receives 1.
        // Net Bob hole1 = gross4 - 1 = 3.  Net Alice = 4.  Bob wins hole 1 outright (net 3 < 4).
        // Need both tied on net hole 1 as well.  Use gross 5 for Bob so net Bob = 5-1 = 4 = Alice.
        // Hole 1 SI 1: Alice gross 4 net 4, Bob gross 5 net 4 → net tie, carry 1.
        // Hole 2 SI 2: Bob HCP 9 ≥ 2 → receives 1. Alice gross 4 net 4, Bob gross 5 net 4 → carry 2.
        let scores = [
            HoleScore(playerID: a.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: b.id, holeNumber: 1, strokes: 5),
            HoleScore(playerID: a.id, holeNumber: 2, strokes: 4),
            HoleScore(playerID: b.id, holeNumber: 2, strokes: 5),
        ]
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: true, gameFormat: .skins)
        let summary = SkinsEngine.compute(input)!

        #expect(summary.pendingCarry == 2, "Carry must accumulate across tied net holes")
        #expect(summary.skinsPerPlayer.isEmpty)
    }

    /// Handicaps ON: carried skins resolve on hole 3 via net logic.
    ///
    /// Holes 1–2 net tied → carry 2.
    /// Hole 3 (SI 3): Bob HCP 9 ≥ 3 → receives 1. Alice gross 5 net 5, Bob gross 5 net 4.
    /// Bob wins net → collects 3 skins.
    @Test func net_handicapsOn_carryResolvesOnLaterHole() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 9)
        // Holes 1,2: SI 1,2 — Bob receives 1 each. Net both 4. (Alice gross 4, Bob gross 5.)
        // Hole 3: SI 3 — Bob receives 1. Alice gross 5 net 5, Bob gross 5 net 4. Bob wins 3.
        let scores = [
            HoleScore(playerID: a.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: b.id, holeNumber: 1, strokes: 5),
            HoleScore(playerID: a.id, holeNumber: 2, strokes: 4),
            HoleScore(playerID: b.id, holeNumber: 2, strokes: 5),
            HoleScore(playerID: a.id, holeNumber: 3, strokes: 5),
            HoleScore(playerID: b.id, holeNumber: 3, strokes: 5),
        ]
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: true, gameFormat: .skins)
        let summary = SkinsEngine.compute(input)!

        #expect(summary.skinsPerPlayer[b.id] == 3, "Bob must collect 3 skins when carry resolves via net on hole 3")
        #expect(summary.pendingCarry == 0)
    }

    // MARK: - Leaderboard / strip consistency

    /// Strip and leaderboard totals must agree under handicaps ON.
    @Test func net_handicapsOn_leaderboardMatchesStrip() {
        let a = PlayerCard(id: UUID(), name: "Alice", handicap: 0)
        let b = PlayerCard(id: UUID(), name: "Bob",   handicap: 9)
        // Bob wins all 3 holes net (receives 1 stroke on SI 1,2,3; gross 5 each; net 4 each).
        // Alice gross 5 → net 5 each hole.  Bob net 4 wins every hole.
        let scores = [
            HoleScore(playerID: a.id, holeNumber: 1, strokes: 5),
            HoleScore(playerID: b.id, holeNumber: 1, strokes: 5),
            HoleScore(playerID: a.id, holeNumber: 2, strokes: 5),
            HoleScore(playerID: b.id, holeNumber: 2, strokes: 5),
            HoleScore(playerID: a.id, holeNumber: 3, strokes: 5),
            HoleScore(playerID: b.id, holeNumber: 3, strokes: 5),
        ]
        let input = RoundInput(course: course, players: [a, b],
                               scores: scores, useHandicaps: true, gameFormat: .skins)
        let summary = SkinsEngine.compute(input)!
        let rows = SkinsEngine.skinsRows(summary: summary, players: [a, b])

        // Bob wins 3 skins via net; leaderboard top row must be Bob
        #expect(rows.first?.id == b.id, "Bob must lead leaderboard with 3 net skins")
        #expect(rows.first?.skinsWon == 3)
        // Strip max must equal leaderboard max
        let stripMax = rows.first?.skinsWon ?? 0
        #expect(stripMax == summary.skinsPerPlayer[b.id])
    }
}

// MARK: - StrokePlay Mode Pipeline Tests
//
// Verifies that Gross vs Net mode produces the correct output at every layer:
//  1. LeaderboardRow totals and deltas
//  2. HoleResult (per-hole label delta)
//  3. Stat bucket counts
//  4. Hole collapsed-badge label derivation logic
//
// Fixture: 2-player, 3-hole course (all par 4).
// Alice HCP=0, Bob HCP=3 (SI 1=h1, SI 2=h2, SI 3=h3 — one stroke per hole).
// Scores: Alice 4,4,4 (even gross); Bob 5,5,5 (+3 gross, even net after 3 strokes).

private let modeTestCourse = CourseLayout(
    pars: [4, 4, 4],
    strokeIndices: [1, 2, 3]
)
private func modeAlice() -> PlayerCard { PlayerCard(id: UUID(), name: "Alice", handicap: 0) }
private func modeBob()   -> PlayerCard { PlayerCard(id: UUID(), name: "Bob",   handicap: 3) }

@Suite("StrokePlayModePipelineTests")
struct StrokePlayModePipelineTests {

    // MARK: - Gross mode totals / deltas

    @Test func grossMode_aliceTotalsAndDelta() {
        let alice = modeAlice(); let bob = modeBob()
        let scores = [
            HoleScore(playerID: alice.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: alice.id, holeNumber: 2, strokes: 4),
            HoleScore(playerID: alice.id, holeNumber: 3, strokes: 4),
            HoleScore(playerID: bob.id,   holeNumber: 1, strokes: 5),
            HoleScore(playerID: bob.id,   holeNumber: 2, strokes: 5),
            HoleScore(playerID: bob.id,   holeNumber: 3, strokes: 5),
        ]
        let input = RoundInput(course: modeTestCourse, players: [alice, bob],
                               scores: scores, useHandicaps: true, gameFormat: .strokePlay)
        let row = StrokePlayEngine.buildRow(for: alice, through: 3, input: input)
        #expect(row.grossTotal == 12)
        #expect(row.grossDelta == 0)   // 12 - par12 = 0
    }

    @Test func grossMode_bobTotalsAndDelta() {
        let alice = modeAlice(); let bob = modeBob()
        let scores = [
            HoleScore(playerID: alice.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: alice.id, holeNumber: 2, strokes: 4),
            HoleScore(playerID: alice.id, holeNumber: 3, strokes: 4),
            HoleScore(playerID: bob.id,   holeNumber: 1, strokes: 5),
            HoleScore(playerID: bob.id,   holeNumber: 2, strokes: 5),
            HoleScore(playerID: bob.id,   holeNumber: 3, strokes: 5),
        ]
        let input = RoundInput(course: modeTestCourse, players: [alice, bob],
                               scores: scores, useHandicaps: true, gameFormat: .strokePlay)
        let row = StrokePlayEngine.buildRow(for: bob, through: 3, input: input)
        #expect(row.grossTotal == 15)
        #expect(row.grossDelta == 3)   // 15 - par12 = +3
    }

    // MARK: - Net mode totals / deltas

    @Test func netMode_aliceNetEqualsGross_zeroHandicap() {
        let alice = modeAlice(); let bob = modeBob()
        let scores = [
            HoleScore(playerID: alice.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: alice.id, holeNumber: 2, strokes: 4),
            HoleScore(playerID: alice.id, holeNumber: 3, strokes: 4),
            HoleScore(playerID: bob.id,   holeNumber: 1, strokes: 5),
            HoleScore(playerID: bob.id,   holeNumber: 2, strokes: 5),
            HoleScore(playerID: bob.id,   holeNumber: 3, strokes: 5),
        ]
        let input = RoundInput(course: modeTestCourse, players: [alice, bob],
                               scores: scores, useHandicaps: true, gameFormat: .strokePlay)
        let row = StrokePlayEngine.buildRow(for: alice, through: 3, input: input)
        // Alice HCP 0 → receives 0 strokes → net == gross
        #expect(row.netTotal == 12)
        #expect(row.netDelta == 0)
    }

    @Test func netMode_bobNetTotalAfterHandicap() {
        let alice = modeAlice(); let bob = modeBob()
        let scores = [
            HoleScore(playerID: alice.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: alice.id, holeNumber: 2, strokes: 4),
            HoleScore(playerID: alice.id, holeNumber: 3, strokes: 4),
            HoleScore(playerID: bob.id,   holeNumber: 1, strokes: 5),
            HoleScore(playerID: bob.id,   holeNumber: 2, strokes: 5),
            HoleScore(playerID: bob.id,   holeNumber: 3, strokes: 5),
        ]
        let input = RoundInput(course: modeTestCourse, players: [alice, bob],
                               scores: scores, useHandicaps: true, gameFormat: .strokePlay)
        let row = StrokePlayEngine.buildRow(for: bob, through: 3, input: input)
        // Bob HCP 3, SI 1/2/3 → 1 stroke on each of holes 1,2,3 → 3 strokes received
        // netTotal = max(0, 15 - 3) = 12; grossPar = 12; netDelta = netTotal - grossPar = 12-12 = 0
        // Par is fixed — strokes received reduce the score, not the par.
        #expect(row.netTotal == 12)     // 15 - 3 received = 12
        #expect(row.netDelta == 0)      // netTotal(12) - grossPar(12) = 0 (E)
        #expect(row.grossDelta == 3)    // gross: 15-12 = +3
    }

    // MARK: - Per-hole result labels (Gross vs Net mode)

    @Test func holeResult_grossMode_bogeyLabel() {
        let bob = modeBob()
        // Bob scores 5 on par 4 hole 1 (SI 1); gross delta = +1 → BGY
        let result = StrokePlayEngine.holeResult(
            for: bob, hole: 1, strokes: 5,
            course: modeTestCourse, useHandicaps: true
        )
        #expect(result.grossDelta == 1)
        #expect(HoleLabel.from(delta: result.grossDelta).text == "BGY")
    }

    @Test func holeResult_netMode_parLabel() {
        let bob = modeBob()
        // Bob scores 5 on par 4 hole 1 (SI 1), receives 1 stroke → net 4 → net delta 0 → PAR
        let result = StrokePlayEngine.holeResult(
            for: bob, hole: 1, strokes: 5,
            course: modeTestCourse, useHandicaps: true
        )
        #expect(result.netDelta == 0)
        #expect(HoleLabel.from(delta: result.netDelta).text == "PAR")
    }

    @Test func holeResult_netMode_birdieLabel() {
        let bob = modeBob()
        // Bob scores 4 on par 4 hole 1 (SI 1), receives 1 stroke → net 3 → net delta -1 → BRD
        let result = StrokePlayEngine.holeResult(
            for: bob, hole: 1, strokes: 4,
            course: modeTestCourse, useHandicaps: true
        )
        #expect(result.netDelta == -1)
        #expect(HoleLabel.from(delta: result.netDelta).text == "BRD")
    }

    // MARK: - HoleLabel mapping (DBL and +N correctness)

    @Test func holeLabel_doubleBogeyIsDbl() {
        #expect(HoleLabel.from(delta: 2).text == "DBL")
    }

    @Test func holeLabel_tripleBogeyIsPlus3() {
        #expect(HoleLabel.from(delta: 3).text == "+3")
    }

    @Test func holeLabel_quadBogeyIsPlus4() {
        #expect(HoleLabel.from(delta: 4).text == "+4")
    }

    @Test func holeLabel_eagleIsEag() {
        #expect(HoleLabel.from(delta: -2).text == "EAG")
    }

    @Test func holeLabel_albatrossIsNumericMinus3() {
        // delta <= -3 uses numeric label e.g. "-3"
        #expect(HoleLabel.from(delta: -3).text == "-3")
    }

    // MARK: - Stat bucket gross vs net mode

    @Test func statBuckets_grossMode_bobShowsBogey() {
        // In gross mode: Bob 5 on par 4 hole 1 → grossDelta +1 → BGY bucket
        let bob = modeBob()
        let result = StrokePlayEngine.holeResult(
            for: bob, hole: 1, strokes: 5,
            course: modeTestCourse, useHandicaps: true
        )
        let grossDelta = result.grossDelta
        // Gross mode: BGY bucket (delta == 1)
        #expect(grossDelta == 1)
        // Confirm it's the BGY category
        var bogeyCount = 0
        if grossDelta == 1 { bogeyCount += 1 }
        #expect(bogeyCount == 1)
    }

    @Test func statBuckets_netMode_bobShowsPar() {
        // In net mode: Bob 5 on par 4 hole 1, SI 1, HCP 3 → receives 1 → netDelta = 0 → PAR bucket
        let bob = modeBob()
        let result = StrokePlayEngine.holeResult(
            for: bob, hole: 1, strokes: 5,
            course: modeTestCourse, useHandicaps: true
        )
        let netDelta = result.netDelta
        #expect(netDelta == 0)
        // Net mode: PAR bucket (delta == 0)
        var parCount = 0
        if netDelta == 0 { parCount += 1 }
        #expect(parCount == 1)
    }

    @Test func statBuckets_grossVsNet_diverge_forHighHandicapper() {
        // Demonstrates that gross and net buckets differ for a handicapped player
        let bob = modeBob()
        let result = StrokePlayEngine.holeResult(
            for: bob, hole: 1, strokes: 5,
            course: modeTestCourse, useHandicaps: true
        )
        // Gross: BGY (+1); Net: PAR (0) — they must differ
        #expect(result.grossDelta != result.netDelta)
        #expect(HoleLabel.from(delta: result.grossDelta).text == "BGY")
        #expect(HoleLabel.from(delta: result.netDelta).text  == "PAR")
    }

    // MARK: - Hole collapsed badge logic (stroke play)
    // Tests the standing-computation logic used by holeCollapsedBadge.
    // We test the domain layer (buildRows) to confirm badge inputs are correct.

    @Test func holeStanding_grossMode_aliceLeadsAfterHole1() {
        let alice = modeAlice(); let bob = modeBob()
        // Alice 4, Bob 5 on hole 1 (par 4) — gross mode: Alice E, Bob +1
        let scores = [
            HoleScore(playerID: alice.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: bob.id,   holeNumber: 1, strokes: 5),
        ]
        let input = RoundInput(course: modeTestCourse, players: [alice, bob],
                               scores: scores, useHandicaps: true, gameFormat: .strokePlay)
        let rows = StrokePlayEngine.buildRows(for: input, through: 1)
        let sorted = rows.sorted {
            if $0.grossDelta != $1.grossDelta { return $0.grossDelta < $1.grossDelta }
            return $0.grossTotal < $1.grossTotal
        }
        #expect(sorted.first?.id == alice.id)
        #expect(sorted.first?.grossDelta == 0)   // E
        #expect(sorted.last?.grossDelta  == 1)   // +1
    }

    @Test func holeStanding_netMode_bobTiedAfterHole1() {
        let alice = modeAlice(); let bob = modeBob()
        // Alice 4 (gross E, net E); Bob 5 (gross +1, net E because receives 1 stroke on SI1)
        let scores = [
            HoleScore(playerID: alice.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: bob.id,   holeNumber: 1, strokes: 5),
        ]
        let input = RoundInput(course: modeTestCourse, players: [alice, bob],
                               scores: scores, useHandicaps: true, gameFormat: .strokePlay)
        let rows = StrokePlayEngine.buildRows(for: input, through: 1)
        let aliceRow = rows.first(where: { $0.id == alice.id })!
        let bobRow   = rows.first(where: { $0.id == bob.id })!
        // Net mode: both at net delta 0 (tied)
        // Alice: grossTotal=4, received=0, netTotal=4, grossPar=4, netDelta=4-4=0
        // Bob:   grossTotal=5, received=1, netTotal=4, grossPar=4, netDelta=4-4=0
        // Par is fixed — strokes received reduce the score, not the par.
        #expect(aliceRow.netDelta == 0)   // Alice: net 4 vs par 4 → E
        #expect(bobRow.netDelta   == 0)   // Bob:   net 4 vs par 4 → E (tied with Alice in net mode)
        // In net mode, Alice and Bob are tied after hole 1.
        let netSorted = rows.sorted { $0.netDelta < $1.netDelta }
        let netSortedDeltas = netSorted.map(\.netDelta)
        #expect(netSortedDeltas.allSatisfy { $0 == 0 }, "Both players tied at E in net mode")
    }

    @Test func holeStanding_allTied_grossMode() {
        let alice = modeAlice(); let bob = modeBob()
        // Both score par → tied in gross mode
        let scores = [
            HoleScore(playerID: alice.id, holeNumber: 1, strokes: 4),
            HoleScore(playerID: bob.id,   holeNumber: 1, strokes: 4),
        ]
        let input = RoundInput(course: modeTestCourse, players: [alice, bob],
                               scores: scores, useHandicaps: true, gameFormat: .strokePlay)
        let rows = StrokePlayEngine.buildRows(for: input, through: 1)
        let allGrossDeltas = rows.map(\.grossDelta)
        #expect(allGrossDeltas.allSatisfy { $0 == allGrossDeltas[0] }, "All players tied at same gross delta")
    }

    // MARK: - Deterministic net mode: par-4, 1 stroke received (exact 4-case matrix)
    // Scenario: hole 1, par 4, SI 1 → player with HCP ≥ 1 receives 1 stroke.
    // net strokes = gross - 1; netDelta = net - par (par is fixed).

    @Test func netDelta_par4_gross4_receives1_isBirdie() {
        // gross 4, net 3, netDelta = 3 - 4 = -1 → BRD
        let player = PlayerCard(id: UUID(), name: "Test", handicap: 1)
        let result = StrokePlayEngine.holeResult(
            for: player, hole: 1, strokes: 4,
            course: modeTestCourse, useHandicaps: true
        )
        #expect(result.netStrokes == 3)
        #expect(result.netDelta   == -1)
        #expect(HoleLabel.from(delta: result.netDelta).text == "BRD")
    }

    @Test func netDelta_par4_gross5_receives1_isPar() {
        // gross 5, net 4, netDelta = 4 - 4 = 0 → PAR
        let player = PlayerCard(id: UUID(), name: "Test", handicap: 1)
        let result = StrokePlayEngine.holeResult(
            for: player, hole: 1, strokes: 5,
            course: modeTestCourse, useHandicaps: true
        )
        #expect(result.netStrokes == 4)
        #expect(result.netDelta   == 0)
        #expect(HoleLabel.from(delta: result.netDelta).text == "PAR")
    }

    @Test func netDelta_par4_gross6_receives1_isBogey() {
        // gross 6, net 5, netDelta = 5 - 4 = +1 → BGY
        let player = PlayerCard(id: UUID(), name: "Test", handicap: 1)
        let result = StrokePlayEngine.holeResult(
            for: player, hole: 1, strokes: 6,
            course: modeTestCourse, useHandicaps: true
        )
        #expect(result.netStrokes == 5)
        #expect(result.netDelta   == 1)
        #expect(HoleLabel.from(delta: result.netDelta).text == "BGY")
    }

    @Test func netDelta_par4_gross7_receives1_isDouble() {
        // gross 7, net 6, netDelta = 6 - 4 = +2 → DBL
        let player = PlayerCard(id: UUID(), name: "Test", handicap: 1)
        let result = StrokePlayEngine.holeResult(
            for: player, hole: 1, strokes: 7,
            course: modeTestCourse, useHandicaps: true
        )
        #expect(result.netStrokes == 6)
        #expect(result.netDelta   == 2)
        #expect(HoleLabel.from(delta: result.netDelta).text == "DBL")
    }
}
