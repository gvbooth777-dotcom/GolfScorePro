//
//  StrokePlayEngine.swift
//  GolfScorePro
//
//  Stroke play scoring engine — pure Swift, no SwiftUI/SwiftData.
//

import Foundation

/// Stateless scoring engine for stroke play (individual, net or gross).
///
/// This extracts and consolidates the scoring computation that was previously
/// duplicated across LiveRoundView and LeaderboardView.
enum StrokePlayEngine {

    // MARK: - Thru-hole computation

    /// Computes the last consecutively-completed hole where all players have a posted score.
    ///
    /// Scans holes 1...N sequentially. Breaks on the first hole where any player
    /// is missing a score. Returns 0 if no hole is fully complete.
    ///
    /// Extracted verbatim from LiveRoundView.computeThruHole() and
    /// LeaderboardView.computeThruHole() (both were identical).
    static func computeThruHole(_ input: RoundInput) -> Int {
        guard !input.players.isEmpty else { return 0 }

        let playerIDs = Set(input.players.map(\.id))
        let holeCount = input.course.holeCount
        guard holeCount > 0 else { return 0 }

        var best = 0
        for h in 1...holeCount {
            let scoredPlayers = Set(
                input.scores
                    .filter { $0.holeNumber == h }
                    .map(\.playerID)
            )
            if scoredPlayers == playerIDs {
                best = h
            } else {
                break
            }
        }
        return best
    }

    // MARK: - Single player row

    /// Builds a leaderboard row for one player through a given hole.
    ///
    /// Extracted from LeaderboardView.buildRow(for:thru:). Net scoring uses
    /// max(0, ...) to floor at zero — identical to existing behavior.
    ///
    /// - Parameters:
    ///   - player: The player card snapshot.
    ///   - thru: Last hole to include (1-based, inclusive).
    ///   - input: The full round snapshot.
    static func buildRow(
        for player: PlayerCard,
        through thru: Int,
        input: RoundInput
    ) -> LeaderboardRow {
        guard thru >= 1 else {
            return LeaderboardRow(
                id: player.id,
                name: player.name,
                grossTotal: 0,
                netTotal: 0,
                grossDelta: 0,
                netDelta: 0
            )
        }

        let grossTotal = input.scores
            .filter { $0.playerID == player.id && $0.holeNumber <= thru }
            .reduce(0) { $0 + $1.strokes }

        let grossPar = (1...thru).reduce(0) { sum, h in
            sum + input.course.par(for: h)
        }

        let received: Int
        if input.useHandicaps {
            received = HandicapAllocator.totalStrokesReceived(
                handicap: player.handicap,
                course: input.course,
                through: thru
            )
        } else {
            received = 0
        }

        let netTotal = max(0, grossTotal - received)

        let grossDelta = grossTotal - grossPar
        // netDelta: net total vs the unadjusted course par.
        // Par is fixed - it does not shrink because a player receives strokes.
        let netDelta   = netTotal - grossPar

        return LeaderboardRow(
            id: player.id,
            name: player.name,
            grossTotal: grossTotal,
            netTotal: netTotal,
            grossDelta: grossDelta,
            netDelta: netDelta
        )
    }

    // MARK: - Full leaderboard (unsorted)

    /// Builds an unsorted array of leaderboard rows for all players through a given hole.
    ///
    /// Sorting is intentionally left to the caller (LeaderboardView.sortedRows) so
    /// the existing gross/net toggle logic in the view layer remains unchanged.
    static func buildRows(
        for input: RoundInput,
        through thru: Int
    ) -> [LeaderboardRow] {
        let effectiveThru = max(1, thru)
        return input.players.map { player in
            buildRow(for: player, through: effectiveThru, input: input)
        }
    }

    // MARK: - Per-hole result (for future LiveRoundView migration)

    /// Computes the scoring result for one player on one hole.
    ///
    /// This is not yet wired to any view — prepared for a future phase where
    /// LiveRoundView migrates its per-hole net display to the domain layer.
    static func holeResult(
        for player: PlayerCard,
        hole: Int,
        strokes: Int,
        course: CourseLayout,
        useHandicaps: Bool
    ) -> HoleResult {
        let par = course.par(for: hole)
        let received: Int
        if useHandicaps {
            received = HandicapAllocator.strokesReceived(
                handicap: player.handicap,
                strokeIndex: course.strokeIndex(for: hole)
            )
        } else {
            received = 0
        }

        let netStrokes = max(1, strokes - received)
        let grossDelta = strokes - par
        // netDelta: net strokes vs the unadjusted hole par.
        // Par is fixed — it does not shrink because a player receives strokes.
        let netDelta   = netStrokes - par

        return HoleResult(
            playerID: player.id,
            grossStrokes: strokes,
            received: received,
            netStrokes: netStrokes,
            netPar: par,         // par is fixed; strokes received don't reduce it
            grossDelta: grossDelta,
            netDelta: netDelta
        )
    }
}
