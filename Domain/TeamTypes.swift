//
//  TeamTypes.swift
//  GolfScorePro
//
//  Domain types for team-based scoring formats.
//  Pure Swift — no SwiftUI, no SwiftData.
//

import Foundation

// MARK: - Team identity

/// Lightweight team identifier in the domain layer.
/// Mirrors PlayerTeam.a/.b from the persistence layer but lives
/// entirely within the domain so engines have no SwiftData dependency.
enum TeamID: String, Sendable, Hashable, CaseIterable {
    case a = "A"
    case b = "B"

    /// Human-readable label (e.g. for display in match summary).
    var label: String { "Team \(rawValue)" }

    /// The opposing team.
    var opponent: TeamID { self == .a ? .b : .a }
}

// MARK: - Team assignment

/// Associates a player with a team for one round.
/// Produced by the bridge layer; consumed by team-aware engines.
struct TeamAssignment: Sendable {
    let playerID: UUID
    let team: TeamID
}

// MARK: - Team score snapshot

/// Aggregated score for one team on one hole (or across holes).
struct TeamScore: Sendable {
    let team: TeamID
    let netStrokes: Int      // best-ball net strokes for this hole/range
    let grossStrokes: Int    // best-ball gross strokes for this hole/range
}
