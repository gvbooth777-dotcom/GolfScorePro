//
//  TeamAggregator.swift
//  GolfScorePro
//
//  Reusable team score aggregation strategies.
//  Pure Swift — no SwiftUI, no SwiftData.
//

import Foundation

/// Strategies for combining multiple players' scores into a single team score.
enum TeamAggregator {

    // MARK: - Best Ball

    /// Returns the lowest net (or gross) strokes among a team's players on one hole.
    ///
    /// If no scores are provided the result is nil (no score posted yet).
    ///
    /// - Parameters:
    ///   - netStrokes: Array of each team member's net strokes on this hole.
    ///   - grossStrokes: Corresponding gross strokes (parallel array, same order).
    /// - Returns: A `TeamScore` with the minimum values, or `nil` if the arrays are empty.
    static func bestBall(
        team: TeamID,
        netStrokes: [Int],
        grossStrokes: [Int]
    ) -> TeamScore? {
        guard !netStrokes.isEmpty, netStrokes.count == grossStrokes.count else { return nil }

        // Best ball = minimum net score; break ties by minimum gross score.
        var bestNet   = netStrokes[0]
        var bestGross = grossStrokes[0]

        for i in 1..<netStrokes.count {
            let n = netStrokes[i]
            let g = grossStrokes[i]
            if n < bestNet || (n == bestNet && g < bestGross) {
                bestNet   = n
                bestGross = g
            }
        }

        return TeamScore(team: team, netStrokes: bestNet, grossStrokes: bestGross)
    }

    // MARK: - Sum All (for Scramble / Total team variants)

    /// Returns the sum of all players' net (and gross) strokes on one hole.
    ///
    /// - Parameters:
    ///   - netStrokes: Array of each team member's net strokes on this hole.
    ///   - grossStrokes: Corresponding gross strokes (parallel array, same order).
    /// - Returns: A `TeamScore` with the summed values, or `nil` if the arrays are empty.
    static func sumAll(
        team: TeamID,
        netStrokes: [Int],
        grossStrokes: [Int]
    ) -> TeamScore? {
        guard !netStrokes.isEmpty, netStrokes.count == grossStrokes.count else { return nil }

        let totalNet   = netStrokes.reduce(0, +)
        let totalGross = grossStrokes.reduce(0, +)

        return TeamScore(team: team, netStrokes: totalNet, grossStrokes: totalGross)
    }
}
