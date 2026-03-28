//
//  SkinsEngine.swift
//  GolfScorePro
//
//  Skins engine — pure Swift, no SwiftUI, no SwiftData.
//
//  Rules:
//    - One skin available per hole.
//    - useHandicaps == false → lowest unique GROSS score wins the hole.
//    - useHandicaps == true  → lowest unique NET score wins the hole.
//      Net score = max(1, gross − strokesReceived) per HandicapAllocator.
//    - Tied low comparison scores carry the skin to the next hole.
//    - When a later hole is won outright, that player collects
//      the current hole skin plus all carried skins.
//    - If the last scored hole ends with a carry, it remains
//      pending — reported via SkinsSummary.pendingCarry.
//

import Foundation

enum SkinsEngine {

    // MARK: - Public entry point

    /// Computes a complete skins summary from a RoundInput.
    ///
    /// Returns `nil` when:
    ///   - no players are present, or
    ///   - no hole has been fully posted (thruHole == 0).
    ///
    /// Only holes where ALL players have posted a score are included.
    ///
    /// - Parameter input: The round snapshot.
    /// - Returns: A `SkinsSummary`, or `nil` if insufficient data.
    static func compute(_ input: RoundInput) -> SkinsSummary? {
        guard !input.players.isEmpty else { return nil }

        let thru = consecutiveThruHole(input: input)
        guard thru >= 1 else { return nil }

        let scoreMap = buildScoreMap(from: input.scores)

        var outcomes: [SkinsHoleOutcome] = []
        var skinsPerPlayer: [UUID: Int] = [:]
        var carry = 0   // skins pot carrying into the current hole

        for hole in 1...thru {
            // Gather scores for every player on this hole.
            // comparison score = net when useHandicaps, gross otherwise.
            let si = input.course.strokeIndex(for: hole)
            let holeScores: [(id: UUID, comparison: Int)] = input.players.compactMap { p in
                guard let gross = scoreMap[p.id]?[hole] else { return nil }
                let compScore: Int
                if input.useHandicaps {
                    let received = HandicapAllocator.strokesReceived(
                        handicap: p.handicap, strokeIndex: si
                    )
                    compScore = max(1, gross - received)
                } else {
                    compScore = gross
                }
                return (p.id, compScore)
            }

            // Need all players scored to settle the hole.
            guard holeScores.count == input.players.count else {
                // Partial hole — don't carry or count.
                outcomes.append(SkinsHoleOutcome(
                    holeNumber: hole,
                    winner: nil,
                    skinsWon: 0,
                    carryOut: carry
                ))
                continue
            }

            let minScore = holeScores.map(\.comparison).min()!
            let winners = holeScores.filter { $0.comparison == minScore }

            if winners.count == 1 {
                // Outright winner collects skin + carry.
                let winnerID = winners[0].id
                let collected = 1 + carry
                skinsPerPlayer[winnerID, default: 0] += collected
                outcomes.append(SkinsHoleOutcome(
                    holeNumber: hole,
                    winner: winnerID,
                    skinsWon: collected,
                    carryOut: 0
                ))
                carry = 0
            } else {
                // Tied — skin carries forward.
                carry += 1
                outcomes.append(SkinsHoleOutcome(
                    holeNumber: hole,
                    winner: nil,
                    skinsWon: 0,
                    carryOut: carry
                ))
            }
        }

        return SkinsSummary(
            holeOutcomes: outcomes,
            skinsPerPlayer: skinsPerPlayer,
            pendingCarry: carry,
            thruHole: thru
        )
    }

    // MARK: - Leaderboard rows

    /// Converts a SkinsSummary into sorted SkinsRow values for display.
    /// All players are included, even those with 0 skins.
    /// Sorted by skinsWon descending, then alphabetically.
    static func skinsRows(
        summary: SkinsSummary?,
        players: [PlayerCard]
    ) -> [SkinsRow] {
        let won = summary?.skinsPerPlayer ?? [:]
        return players
            .map { SkinsRow(id: $0.id, name: $0.name, skinsWon: won[$0.id] ?? 0) }
            .sorted {
                if $0.skinsWon != $1.skinsWon { return $0.skinsWon > $1.skinsWon }
                return $0.name < $1.name
            }
    }

    // MARK: - Private helpers

    private static func buildScoreMap(from scores: [HoleScore]) -> [UUID: [Int: Int]] {
        var map: [UUID: [Int: Int]] = [:]
        for s in scores {
            map[s.playerID, default: [:]][s.holeNumber] = s.strokes
        }
        return map
    }

    /// Last consecutive hole where all players have a posted score.
    private static func consecutiveThruHole(input: RoundInput) -> Int {
        let playerIDs = Set(input.players.map(\.id))
        let scoreMap = buildScoreMap(from: input.scores)
        var thru = 0
        for h in 1...input.course.holeCount {
            let allPosted = playerIDs.allSatisfy { scoreMap[$0]?[h] != nil }
            if allPosted { thru = h } else { break }
        }
        return thru
    }
}
