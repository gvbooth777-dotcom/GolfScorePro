//
//  SkinsTypes.swift
//  GolfScorePro
//
//  Output models for SkinsEngine.
//  Pure Swift — no SwiftUI, no SwiftData.
//

import Foundation

// MARK: - Per-hole outcome

/// The result of one hole in a skins contest.
struct SkinsHoleOutcome: Sendable {
    /// 1-based hole number.
    let holeNumber: Int
    /// ID of the player who won the skin, or nil if the hole was tied (carry).
    let winner: UUID?
    /// Skins collected on this hole by the winner (1 + carry-in). Zero when tied.
    let skinsWon: Int
    /// Number of skins carrying into the next hole after this one.
    let carryOut: Int
}

// MARK: - Full summary (engine output)

/// Complete skins result produced by SkinsEngine.
struct SkinsSummary: Sendable {
    /// Hole-by-hole outcomes (holes 1 through thruHole).
    let holeOutcomes: [SkinsHoleOutcome]
    /// Total skins won per player (keyed by player ID). Players with 0 skins are omitted.
    let skinsPerPlayer: [UUID: Int]
    /// Skins currently in the carry pot — unresolved at end of thruHole.
    let pendingCarry: Int
    /// Last hole included in this summary (0 if no holes scored yet).
    let thruHole: Int
}

// MARK: - Leaderboard row (UI output)

/// One row in a skins leaderboard, produced by SkinsEngine.skinsRows().
struct SkinsRow: Sendable, Identifiable {
    let id: UUID       // player ID
    let name: String
    let skinsWon: Int
}
