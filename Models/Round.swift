//
//  Round.swift
//  GolfScorePro
//
//  Refactor: 2026-02-12 16:10 PT
//
import Foundation
import SwiftData

enum RoundStatus: String, Codable {
    case inProgress
    case completed
}

// Persisted game types are stored as raw strings for stability/migrations.
enum RoundGameType: String, Codable, CaseIterable {
    case strokePlay = "strokePlay"
    case matchPlay  = "matchPlay"
    case skins      = "skins"

    var displayName: String {
        switch self {
        case .strokePlay: return "Stroke Play"
        case .matchPlay:  return "Match Play"
        case .skins:      return "Skins"
        }
    }
}

@Model
final class Round {
    var id: UUID
    var courseName: String
    var totalHoles: Int
    var createdAt: Date
    var status: RoundStatus
    var currentHole: Int
    var players: [Player]
    var scores: [Score]

    /// Per-hole par values, index 0 = hole 1, etc.
    var pars: [Int]

    /// Optional link to a saved Course record (for reference/history)
    var course: Course?

    /// Stroke index per hole for this round (frozen at round creation)
    var strokeIndex: [Int]

    // MARK: - ✅ Game scaffolding (persisted)

    /// Stored as raw string for SwiftData stability.
    /// Defaults to Stroke Play so older saved rounds load cleanly.
    var gameTypeRaw: String = RoundGameType.strokePlay.rawValue

    /// Whether handicaps are intended to be used for this round (net scoring, allocations).
    /// GVB Assumes true
    var useHandicaps: Bool = true

    /// ✅ NEW: whether this round is using team play
    var teamPlay: Bool = false

    /// Convenience computed property (not stored directly)
    var gameType: RoundGameType {
        get { RoundGameType(rawValue: gameTypeRaw) ?? .strokePlay }
        set { gameTypeRaw = newValue.rawValue }
    }

    init(courseName: String,
         totalHoles: Int = 18,
         createdAt: Date = .now,
         status: RoundStatus = .inProgress,
         currentHole: Int = 1,
         players: [Player] = [],
         scores: [Score] = [],
         pars: [Int]? = nil,
         strokeIndex: [Int]? = nil,
         course: Course? = nil,
         // ✅ new (optional) params for game scaffolding
         gameType: RoundGameType = .strokePlay,
         useHandicaps: Bool? = nil,
         // ✅ new (optional) param for teams
         teamPlay: Bool = false) {

        let finalPars = pars ?? Array(repeating: 4, count: totalHoles)

        let finalStrokeIndex: [Int]
        if let strokeIndex {
            finalStrokeIndex = strokeIndex
        } else {
            finalStrokeIndex = Array(1...finalPars.count)
        }

        self.id = UUID()
        self.courseName = courseName
        self.totalHoles = finalPars.count
        self.createdAt = createdAt
        self.status = status
        self.currentHole = currentHole
        self.players = players
        self.scores = scores
        self.pars = finalPars
        self.strokeIndex = Array(finalStrokeIndex.prefix(finalPars.count))
        self.course = course

        // ✅ Game scaffolding defaults:
        // GVB took out else if .strokeplay...
        self.gameTypeRaw = gameType.rawValue
        if let useHandicaps {
            self.useHandicaps = useHandicaps
        }

        // ✅ Team play
        self.teamPlay = teamPlay
    }

    /// Par for a specific hole (1-based). Defaults to 4 if out of range.
    func parForHole(_ hole: Int) -> Int {
        guard hole >= 1, hole <= pars.count else { return 4 }
        return pars[hole - 1]
    }

    /// Stroke index for a specific hole (1-based). Defaults to hole number if out of range.
    func strokeIndexForHole(_ hole: Int) -> Int {
        guard hole >= 1, hole <= strokeIndex.count else { return hole }
        return strokeIndex[hole - 1]
    }

    /// Total par for the round.
    var totalPar: Int {
        pars.reduce(0, +)
    }
}
