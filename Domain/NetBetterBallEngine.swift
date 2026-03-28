//
//  NetBetterBallEngine.swift
//  GolfScorePro
//
//  2v2 Net Better Ball Match Play engine.
//  Pure Swift — no SwiftUI, no SwiftData.
//
//  Handicap rule (v1 — 100% allowance):
//    Each player's playing handicap is their full handicap minus the
//    lowest handicap in the group (floor 0). Strokes are allocated by
//    stroke index across holes in the normal way.
//

import Foundation

enum NetBetterBallEngine {

    // MARK: - Public entry point

    /// Computes a complete 2v2 net better ball match play summary from a RoundInput.
    ///
    /// Returns `nil` when:
    ///   - fewer than 2 players are assigned to each team, or
    ///   - no scores have been posted yet.
    ///
    /// The engine only scores holes where ALL four players have a posted score.
    /// Partially-posted holes are not included.
    ///
    /// - Parameter input: The round snapshot (must have teamPlay players).
    /// - Returns: A `MatchSummary`, or `nil` if insufficient data.
    static func compute(_ input: RoundInput) -> MatchSummary? {
        // Split players by team.
        let teamA = input.players.filter { $0.team == .a }
        let teamB = input.players.filter { $0.team == .b }
        guard !teamA.isEmpty, !teamB.isEmpty else { return nil }

        // Playing handicaps = full handicap - lowest handicap in the group (floor 0).
        // When useHandicaps is false, all playing handicaps are 0 (gross-only comparison).
        let allPlayers = input.players
        let playingHandicaps: [UUID: Int]
        if input.useHandicaps {
            let minHandicap = allPlayers.map(\.handicap).min() ?? 0
            playingHandicaps = Dictionary(
                uniqueKeysWithValues: allPlayers.map { p in
                    (p.id, max(0, p.handicap - minHandicap))
                }
            )
        } else {
            playingHandicaps = Dictionary(
                uniqueKeysWithValues: allPlayers.map { p in (p.id, 0) }
            )
        }

        // Build a lookup: [playerID: [holeNumber: strokes]]
        let scoreMap = buildScoreMap(from: input.scores)

        // Find the last consecutive hole where all players have a score.
        let allPlayerIDs = Set(allPlayers.map(\.id))
        let thru = consecutiveThruHole(
            allPlayerIDs: allPlayerIDs,
            scoreMap: scoreMap,
            holeCount: input.course.holeCount
        )
        guard thru >= 1 else { return nil }

        // Compute hole-by-hole outcomes.
        var outcomes: [TeamHoleOutcome] = []
        var holesWonA = 0
        var holesWonB = 0
        var holesHalved = 0
        var matchClosed = false
        var closedAtHole: Int? = nil

        for hole in 1...thru {
            // Early-finish: if match already decided, stop computing.
            if matchClosed { break }

            let par = input.course.par(for: hole)
            let si  = input.course.strokeIndex(for: hole)

            // Compute each player's net strokes for this hole.
            func netStrokes(for player: PlayerCard) -> Int? {
                guard let gross = scoreMap[player.id]?[hole] else { return nil }
                let ph = playingHandicaps[player.id] ?? 0
                let received = HandicapAllocator.strokesReceived(handicap: ph, strokeIndex: si)
                return max(1, gross - received)
            }

            func grossStrokes(for player: PlayerCard) -> Int? {
                return scoreMap[player.id]?[hole]
            }

            // Gather valid net/gross scores for each team.
            let teamANet   = teamA.compactMap { netStrokes(for: $0) }
            let teamAGross = teamA.compactMap { grossStrokes(for: $0) }
            let teamBNet   = teamB.compactMap { netStrokes(for: $0) }
            let teamBGross = teamB.compactMap { grossStrokes(for: $0) }

            // Need at least one score per team to determine the hole.
            guard !teamANet.isEmpty, !teamBNet.isEmpty else { continue }

            // Best ball per team.
            guard
                let bbA = TeamAggregator.bestBall(team: .a, netStrokes: teamANet, grossStrokes: teamAGross),
                let bbB = TeamAggregator.bestBall(team: .b, netStrokes: teamBNet, grossStrokes: teamBGross)
            else { continue }

            // Determine hole winner (net comparison).
            let holeWinner: TeamID?
            if bbA.netStrokes < bbB.netStrokes {
                holeWinner = .a
                holesWonA += 1
            } else if bbB.netStrokes < bbA.netStrokes {
                holeWinner = .b
                holesWonB += 1
            } else {
                holeWinner = nil
                holesHalved += 1
            }

            _ = par // retained for future gross-delta display

            // Compute running match status.
            let holesRemaining = input.course.holeCount - hole
            let status = computeStatus(
                holesWonA: holesWonA,
                holesWonB: holesWonB,
                holesRemaining: holesRemaining,
                holeNumber: hole,
                holeCount: input.course.holeCount
            )

            // Detect early finish.
            if case .won = status {
                matchClosed = true
                closedAtHole = hole
            }

            outcomes.append(TeamHoleOutcome(
                holeNumber: hole,
                teamANet: bbA.netStrokes,
                teamBNet: bbB.netStrokes,
                winner: holeWinner,
                runningStatus: status
            ))
        }

        // Final status from last computed outcome (or all-square if no holes played).
        let finalStatus = outcomes.last?.runningStatus ?? .allSquare(holesRemaining: input.course.holeCount)

        return MatchSummary(
            holeOutcomes: outcomes,
            holesWonA: holesWonA,
            holesWonB: holesWonB,
            holesHalved: holesHalved,
            status: finalStatus
        )
    }

    // MARK: - Output: TeamMatchRows

    /// Converts a MatchSummary into two TeamMatchRow values for leaderboard display.
    /// Returns an empty array if summary is nil.
    static func teamMatchRows(
        summary: MatchSummary?,
        players: [PlayerCard]
    ) -> [TeamMatchRow] {
        guard let summary else { return [] }

        let leadA: Bool
        let leadB: Bool
        let statusA: String
        let statusB: String

        switch summary.status {
        case .allSquare:
            leadA = false; leadB = false
            statusA = "AS"; statusB = "AS"
        case .leading(let side, let lead, _):
            leadA = side == .a; leadB = side == .b
            statusA = side == .a ? "\(lead) UP" : "\(lead) DN"
            statusB = side == .b ? "\(lead) UP" : "\(lead) DN"
        case .won(let winner, let result):
            leadA = winner == .a; leadB = winner == .b
            statusA = winner == .a ? result : "Lost \(result)"
            statusB = winner == .b ? result : "Lost \(result)"
        case .halved:
            leadA = false; leadB = false
            statusA = "Halved"; statusB = "Halved"
        }

        let namesA = players.filter { $0.team == .a }.map(\.name)
        let namesB = players.filter { $0.team == .b }.map(\.name)

        return [
            TeamMatchRow(
                id: .a,
                teamLabel: TeamID.a.label,
                holesWon: summary.holesWonA,
                holesHalved: summary.holesHalved,
                isLeading: leadA,
                statusText: statusA,
                playerNames: namesA
            ),
            TeamMatchRow(
                id: .b,
                teamLabel: TeamID.b.label,
                holesWon: summary.holesWonB,
                holesHalved: summary.holesHalved,
                isLeading: leadB,
                statusText: statusB,
                playerNames: namesB
            )
        ]
    }

    // MARK: - Private helpers

    private static func buildScoreMap(from scores: [HoleScore]) -> [UUID: [Int: Int]] {
        var map: [UUID: [Int: Int]] = [:]
        for s in scores {
            map[s.playerID, default: [:]][s.holeNumber] = s.strokes
        }
        return map
    }

    /// Last consecutive hole where all players in `allPlayerIDs` have a score.
    private static func consecutiveThruHole(
        allPlayerIDs: Set<UUID>,
        scoreMap: [UUID: [Int: Int]],
        holeCount: Int
    ) -> Int {
        guard holeCount > 0 else { return 0 }
        var thru = 0
        for h in 1...holeCount {
            let allPosted = allPlayerIDs.allSatisfy { scoreMap[$0]?[h] != nil }
            if allPosted {
                thru = h
            } else {
                break
            }
        }
        return thru
    }

    /// Computes match status after a hole is resolved.
    private static func computeStatus(
        holesWonA: Int,
        holesWonB: Int,
        holesRemaining: Int,
        holeNumber: Int,
        holeCount: Int
    ) -> MatchStatus {
        let lead = holesWonA - holesWonB

        guard lead != 0 else {
            return .allSquare(holesRemaining: holesRemaining)
        }

        let leadingSide: TeamID = lead > 0 ? .a : .b
        let leadMagnitude = abs(lead)

        // All remaining holes played — match over on the last hole with a lead.
        if holesRemaining == 0 {
            return .won(winner: leadingSide, result: "\(leadMagnitude) UP")
        }

        // Early finish: lead strictly exceeds holes remaining (with holes still left to play).
        if leadMagnitude > holesRemaining {
            let result = earlyFinishText(lead: leadMagnitude, remaining: holesRemaining)
            return .won(winner: leadingSide, result: result)
        }

        return .leading(side: leadingSide, by: leadMagnitude, holesRemaining: holesRemaining)
    }

    /// Formats an early-finish result string, e.g. "3&2", "5&4".
    private static func earlyFinishText(lead: Int, remaining: Int) -> String {
        "\(lead)&\(remaining)"
    }

    // MARK: - DEBUG diagnostic (temporary — remove before release)

#if DEBUG
    /// Produces a human-readable trace of the engine's internal calculations for one round.
    ///
    /// Prints, for each player:
    ///   - raw handicap and playing handicap (differential from lowest)
    ///   - strokes received on each hole by stroke index
    ///   - gross score, strokes received, and net score per hole
    ///   - which player's score was selected as the team's better ball on each hole
    ///
    /// Returns the trace as a single String so callers can print or assert against it.
    /// Does NOT modify any state and has no effect on `compute()`.
    @discardableResult
    static func diagnosticTrace(_ input: RoundInput) -> String {
        var out: [String] = []

        let allPlayers = input.players.sorted { $0.name < $1.name }
        let minHandicap = allPlayers.map(\.handicap).min() ?? 0
        let playingHandicaps: [UUID: Int] = Dictionary(
            uniqueKeysWithValues: allPlayers.map { p in
                (p.id, max(0, p.handicap - minHandicap))
            }
        )
        let scoreMap = buildScoreMap(from: input.scores)
        let holeCount = input.course.holeCount

        // ── Header ──────────────────────────────────────────────────────────
        out.append("=== NetBetterBall Diagnostic (\(holeCount)-hole course) ===")
        out.append("useHandicaps: \(input.useHandicaps)  lowestHCP: \(minHandicap)")
        out.append("")

        // ── Per-player handicap and stroke-allocation table ──────────────────
        out.append("Player          rawHCP  playHCP  strokesReceivedPerHole (hole 1…\(holeCount))")
        out.append(String(repeating: "-", count: 80))
        for p in allPlayers {
            let ph = playingHandicaps[p.id] ?? 0
            let strokes: [Int] = (1...holeCount).map { hole in
                input.useHandicaps
                    ? HandicapAllocator.strokesReceived(handicap: ph, strokeIndex: input.course.strokeIndex(for: hole))
                    : 0
            }
            let strokeStr = strokes.map { String($0) }.joined(separator: " ")
            let team = p.team.map { " [\($0.rawValue)]" } ?? ""
            out.append(String(format: "%-14s  %6d  %7d  %@",
                              (p.name + team) as NSString, p.handicap, ph, strokeStr))
        }
        out.append("")

        // ── Per-hole scoring detail ──────────────────────────────────────────
        let allPlayerIDs = Set(allPlayers.map(\.id))
        let thru = consecutiveThruHole(allPlayerIDs: allPlayerIDs, scoreMap: scoreMap, holeCount: holeCount)
        out.append("Holes scored (consecutive thru): \(thru == 0 ? "none" : "\(thru)")")
        out.append("")

        if thru >= 1 {
            // Column header
            let nameCol = allPlayers.map { p -> String in
                let ph = playingHandicaps[p.id] ?? 0
                return "\(p.name)(ph\(ph))"
            }.joined(separator: "  ")
            out.append("Hole  Par  SI  \(nameCol)  │  TeamA_best  TeamB_best  Winner")
            out.append(String(repeating: "-", count: 100))

            var matchClosed = false
            var runA = 0, runB = 0

            for hole in 1...thru {
                guard !matchClosed else { break }

                let par = input.course.par(for: hole)
                let si  = input.course.strokeIndex(for: hole)

                // Per-player gross / received / net
                var perPlayer: [(player: PlayerCard, gross: Int, recv: Int, net: Int)] = []
                for p in allPlayers {
                    guard let gross = scoreMap[p.id]?[hole] else { continue }
                    let ph = playingHandicaps[p.id] ?? 0
                    let recv = input.useHandicaps
                        ? HandicapAllocator.strokesReceived(handicap: ph, strokeIndex: si)
                        : 0
                    let net = max(1, gross - recv)
                    perPlayer.append((p, gross, recv, net))
                }

                // Team best-ball selection
                let teamARows = perPlayer.filter { $0.player.team == .a }
                let teamBRows = perPlayer.filter { $0.player.team == .b }

                let bestA = teamARows.min { a, b in
                    a.net < b.net || (a.net == b.net && a.gross < b.gross)
                }
                let bestB = teamBRows.min { a, b in
                    a.net < b.net || (a.net == b.net && a.gross < b.gross)
                }

                let winner: String
                if let a = bestA, let b = bestB {
                    if a.net < b.net       { winner = "A (\(bestA!.player.name))"; runA += 1 }
                    else if b.net < a.net  { winner = "B (\(bestB!.player.name))"; runB += 1 }
                    else                   { winner = "halved" }
                } else {
                    winner = "—"
                }

                // Build player detail columns: "gross-recv=net"
                let playerCols = allPlayers.map { p -> String in
                    if let row = perPlayer.first(where: { $0.player.id == p.id }) {
                        let isBB = (row.player.team == .a && bestA?.player.id == row.player.id)
                                || (row.player.team == .b && bestB?.player.id == row.player.id)
                        let marker = isBB ? "*" : " "
                        return "\(row.gross)-\(row.recv)=\(row.net)\(marker)"
                    }
                    return "—"
                }.joined(separator: "  ")

                let aBest = bestA.map { "\($0.net)" } ?? "—"
                let bBest = bestB.map { "\($0.net)" } ?? "—"
                out.append("H\(String(format: "%02d", hole))   \(par)    \(String(format: "%2d", si))  \(playerCols)  │  \(aBest)            \(bBest)          \(winner)")

                // Early-finish detection (mirrors engine logic)
                let remaining = holeCount - hole
                let lead = runA - runB
                if remaining == 0 && lead != 0 {
                    matchClosed = true
                } else if lead != 0 && abs(lead) > remaining {
                    matchClosed = true
                }
            }

            out.append("")
            out.append("Running totals: Team A \(runA) holes won, Team B \(runB) holes won")
        }

        out.append("=== end diagnostic ===")
        let trace = out.joined(separator: "\n")
        return trace
    }
#endif
}
