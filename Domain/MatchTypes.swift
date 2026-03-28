//
//  MatchTypes.swift
//  GolfScorePro
//
//  Match play state types and output models.
//  Pure Swift — no SwiftUI, no SwiftData.
//

import Foundation

// MARK: - Match status

/// The current standing of a match play contest at a point in the round.
enum MatchStatus: Sendable, Equatable {
    /// One side is leading by `holes` holes with `remaining` holes left.
    case leading(side: TeamID, by: Int, holesRemaining: Int)
    /// All square — neither side leads.
    case allSquare(holesRemaining: Int)
    /// The match is over: leading side clinched, result text e.g. "3&2".
    case won(winner: TeamID, result: String)
    /// The match ended in a tie after all holes.
    case halved

    // MARK: Display

    /// Short status string shown in the scoreboard (e.g. "AS", "2 UP", "3&2").
    var statusText: String {
        switch self {
        case .allSquare:
            return "AS"
        case .leading(let side, let lead, _):
            return "\(lead) UP (\(side.label))"
        case .won(_, let result):
            return result
        case .halved:
            return "Halved"
        }
    }

    /// True when the match cannot be won by the trailing side with holes remaining.
    /// (e.g. leading 2 up with 1 hole left = dormie.)
    var isDormie: Bool {
        switch self {
        case .leading(_, let lead, let remaining):
            return lead == remaining
        default:
            return false
        }
    }
}

// MARK: - Per-hole team outcome

/// The result of one hole in a team match play contest.
struct TeamHoleOutcome: Sendable {
    let holeNumber: Int
    let teamANet: Int          // team A best-ball net strokes
    let teamBNet: Int          // team B best-ball net strokes
    let winner: TeamID?        // nil = halved
    let runningStatus: MatchStatus
}

// MARK: - Match summary (engine output)

/// Complete match play result produced by NetBetterBallEngine.
/// Ready for direct use in LeaderboardView / LiveRoundView UI.
struct MatchSummary: Sendable {
    /// Hole-by-hole outcomes (holes 1 through thruHole).
    let holeOutcomes: [TeamHoleOutcome]

    /// Holes won by each team.
    let holesWonA: Int
    let holesWonB: Int
    /// Holes halved (neither team won).
    let holesHalved: Int

    /// Current/final match status.
    let status: MatchStatus

    /// Convenience: thru which hole this summary was computed.
    var thruHole: Int { holeOutcomes.last?.holeNumber ?? 0 }
}

// MARK: - Team match row (for leaderboard UI)

/// One row in a team-format leaderboard.
/// Replaces the placeholder per-player row in gamePlaceholderSection for match play.
struct TeamMatchRow: Sendable, Identifiable {
    let id: TeamID          // team A or B
    let teamLabel: String   // "Team A" / "Team B"
    let holesWon: Int
    let holesHalved: Int
    /// True when this team is currently winning the match.
    let isLeading: Bool
    /// Short status text for this team (e.g. "2 UP", "AS", "1 DN").
    let statusText: String
    /// Player names on this team (for display).
    let playerNames: [String]
}
