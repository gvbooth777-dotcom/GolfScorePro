//
//  Score.swift
//  GolfScorePro
//
//  Created by Greg Booth on 12/2/25.
//

import Foundation
import SwiftData

@Model
final class Score {
    var id: UUID

    /// The player this score belongs to
    var player: Player

    /// The round this score belongs to
    var round: Round

    /// Hole number (1-based)
    var holeNumber: Int

    /// Number of strokes taken
    var strokes: Int

    init(player: Player, round: Round, holeNumber: Int, strokes: Int) {
        self.id = UUID()
        self.player = player
        self.round = round
        self.holeNumber = holeNumber
        self.strokes = strokes
    }
}

