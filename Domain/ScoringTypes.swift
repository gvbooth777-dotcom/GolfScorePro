//
//  ScoringTypes.swift
//  GolfScorePro
//
//  Domain layer value types — pure Swift, no SwiftUI/SwiftData.
//

import Foundation

// MARK: - Game format (decoupled from RoundGameType persistence enum)

enum GameFormat: String, Sendable {
    case strokePlay
    case matchPlay
    case skins
}

// MARK: - Course layout snapshot

/// Everything the scoring engine needs about a course's layout.
/// Constructed once from a Round's snapshotted pars/strokeIndex arrays.
struct CourseLayout: Sendable {
    /// Total number of holes.
    let holeCount: Int

    // 1-based storage: index 0 is unused so index == hole number.
    private let _pars: [Int]
    private let _strokeIndices: [Int]

    /// Create from the 0-based arrays as stored in the Round model.
    init(pars: [Int], strokeIndices: [Int]) {
        self.holeCount = pars.count
        self._pars = [0] + pars
        self._strokeIndices = [0] + strokeIndices
    }

    func par(for hole: Int) -> Int {
        guard hole >= 1, hole <= holeCount else { return 4 }
        return _pars[hole]
    }

    func strokeIndex(for hole: Int) -> Int {
        guard hole >= 1, hole <= holeCount else { return hole }
        return _strokeIndices[hole]
    }

    /// Total par across all holes.
    var totalPar: Int {
        guard holeCount > 0 else { return 0 }
        return (1...holeCount).reduce(0) { $0 + par(for: $1) }
    }
}

// MARK: - Player snapshot

/// Lightweight player identity + handicap for scoring computations.
/// Decoupled from the SwiftData Player model.
struct PlayerCard: Sendable, Identifiable {
    let id: UUID
    let name: String
    let handicap: Int
    /// Optional team assignment. nil for individual (stroke play / skins) rounds.
    let team: TeamID?

    /// Convenience initialiser that preserves backward-compatible default (nil team).
    init(id: UUID, name: String, handicap: Int, team: TeamID? = nil) {
        self.id = id
        self.name = name
        self.handicap = handicap
        self.team = team
    }
}

// MARK: - Score snapshot

/// A single posted score: which player, which hole, how many strokes.
struct HoleScore: Sendable {
    let playerID: UUID
    let holeNumber: Int  // 1-based
    let strokes: Int
}

// MARK: - Round input

/// Complete scoring snapshot of a round.
/// Constructed from the SwiftData Round model via RoundInput+Bridge.swift.
/// This is the single bridge point between persistence and the domain layer.
struct RoundInput: Sendable {
    let course: CourseLayout
    let players: [PlayerCard]
    let scores: [HoleScore]
    let useHandicaps: Bool
    let gameFormat: GameFormat
}

// MARK: - Engine output types

/// Leaderboard row produced by StrokePlayEngine.
/// Replaces the private LBRow type that was embedded in LeaderboardView.
struct LeaderboardRow: Sendable, Identifiable {
    let id: UUID       // player ID
    let name: String
    let grossTotal: Int
    let netTotal: Int
    let grossDelta: Int  // grossTotal - grossPar
    let netDelta: Int    // netTotal - netPar
}

/// Per-hole scoring result for a single player.
/// Used by StrokePlayEngine.holeResult — prepared for future LiveRoundView migration.
struct HoleResult: Sendable {
    let playerID: UUID
    let grossStrokes: Int
    let received: Int
    let netStrokes: Int   // max(1, grossStrokes - received)
    let netPar: Int       // max(1, par - received)
    let grossDelta: Int   // grossStrokes - par
    let netDelta: Int     // netStrokes - netPar
}

// MARK: - Hole label

/// Display label for a single-hole gross delta.
/// Extracts the resultLabel(for:) logic currently in LiveRoundView.
enum HoleLabel: Sendable {
    case eagle          // -2
    case birdie         // -1
    case par            //  0
    case bogey          // +1
    case doubleBogey    // +2
    case numeric(Int)   // -3 and below, or +3 and above

    var text: String {
        switch self {
        case .eagle:            return "EAG"
        case .birdie:           return "BRD"
        case .par:              return "PAR"
        case .bogey:            return "BGY"
        case .doubleBogey:      return "DBL"
        case .numeric(let d):
            if d <= -3 { return "\(d)" }
            return "+\(d)"
        }
    }

    static func from(delta: Int) -> HoleLabel {
        switch delta {
        case ...(-3): return .numeric(delta)
        case -2:      return .eagle
        case -1:      return .birdie
        case 0:       return .par
        case 1:       return .bogey
        case 2:       return .doubleBogey
        default:      return .numeric(delta)
        }
    }
}
