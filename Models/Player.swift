//
//  Player.swift
//  GolfScorePro
//
//  Created by Greg Booth on 12/2/25.
//

import Foundation
import SwiftData

// Persisted team values as raw strings for stability.
enum PlayerTeam: String, Codable, CaseIterable, Identifiable {
    case a = "A"
    case b = "B"

    var id: String { rawValue }
    var label: String { "Team \(rawValue)" }
}

@Model
final class Player {
    var id: UUID
    var name: String
    var handicap: Int

    /// ✅ Persisted team (raw string) for SwiftData stability.
    /// Default A so older/blank players load consistently.
    var teamRaw: String = PlayerTeam.a.rawValue

    /// Convenience computed property (not stored directly)
    var team: PlayerTeam {
        get { PlayerTeam(rawValue: teamRaw) ?? .a }
        set { teamRaw = newValue.rawValue }
    }

    init(name: String, handicap: Int = 0, team: PlayerTeam = .a) {
        self.id = UUID()
        self.name = name
        self.handicap = handicap
        self.teamRaw = team.rawValue
    }
}
