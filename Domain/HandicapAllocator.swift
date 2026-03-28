//
//  HandicapAllocator.swift
//  GolfScorePro
//
//  Pure handicap stroke allocation — no SwiftUI/SwiftData.
//

import Foundation

/// Computes how many handicap strokes a player receives on a given hole.
///
/// Algorithm (standard golf SI allocation):
///   Given a player's handicap and a hole's stroke index (SI), the player
///   receives 1 stroke each time their handicap "covers" that SI value.
///   Start threshold at SI, increment by 18 each pass.
///   While handicap >= threshold: received += 1, threshold += 18.
///
/// Examples (18-hole course with SI 1..18):
///   - HCP 10, SI  8  → 1  (10 >= 8; 10 < 26)
///   - HCP 10, SI 12  → 0  (10 < 12)
///   - HCP 20, SI  2  → 2  (20 >= 2; 20 >= 20; 20 < 38)
///   - HCP  0, SI  1  → 0
///   - HCP 36, SI  1  → 2  (36 >= 1; 36 >= 19; 36 < 37)
///   - HCP 36, SI 18  → 2  (36 >= 18; 36 >= 36; 36 < 54)
///   - HCP 18, any SI → 1  (covers exactly one full pass)
///
/// This algorithm is extracted verbatim from:
///   - LiveRoundView.strokesReceivedThisHole(for:)
///   - LeaderboardView.strokesReceived(for:hole:)
///
enum HandicapAllocator {

    /// Returns the number of strokes a player receives on a single hole.
    ///
    /// - Parameters:
    ///   - handicap: The player's playing handicap (0 or positive integer).
    ///   - strokeIndex: The hole's stroke index (1-based, typically 1...18).
    /// - Returns: Number of strokes received (0, 1, 2, …).
    static func strokesReceived(handicap: Int, strokeIndex: Int) -> Int {
        guard handicap > 0 else { return 0 }

        var received = 0
        var threshold = strokeIndex

        while handicap >= threshold {
            received += 1
            threshold += 18
        }
        return received
    }

    /// Total strokes received by a player across holes 1...thru.
    ///
    /// - Parameters:
    ///   - handicap: The player's playing handicap.
    ///   - course: The course layout (used to look up each hole's stroke index).
    ///   - hole: The last hole to include (inclusive, 1-based).
    /// - Returns: Total strokes received across all holes up to and including `hole`.
    static func totalStrokesReceived(
        handicap: Int,
        course: CourseLayout,
        through hole: Int
    ) -> Int {
        guard handicap > 0, hole >= 1 else { return 0 }
        let lastHole = min(hole, course.holeCount)
        guard lastHole >= 1 else { return 0 }
        return (1...lastHole).reduce(0) { sum, h in
            sum + strokesReceived(handicap: handicap, strokeIndex: course.strokeIndex(for: h))
        }
    }
}
