//
//  RoundInput+Bridge.swift
//  GolfScorePro
//
//  Bridge: constructs a domain RoundInput snapshot from the SwiftData Round model.
//
//  This is the ONLY domain file that references SwiftData model types.
//  All other domain files (ScoringTypes, HandicapAllocator, StrokePlayEngine,
//  MatchState) are pure Swift with no dependency on the persistence layer.
//

import Foundation

extension RoundInput {

    /// Constructs a RoundInput snapshot from a persisted Round.
    ///
    /// This is a pure read — no mutations, no SwiftData context required.
    /// The Round's relationship arrays (players, scores) are read as-is.
    /// Call this once at the top of any scoring computation that starts from a Round.
    ///
    /// - Parameter round: The SwiftData Round model to snapshot.
    init(from round: Round) {
        let course = CourseLayout(
            pars: round.pars,
            strokeIndices: round.strokeIndex
        )

        let players = round.players.map { p in
            let teamID: TeamID? = round.teamPlay ? (p.team == .a ? .a : .b) : nil
            return PlayerCard(
                id: p.id,
                name: p.name,
                handicap: p.handicap,
                team: teamID
            )
        }

        let scores = round.scores.map { s in
            HoleScore(
                playerID: s.player.id,
                holeNumber: s.holeNumber,
                strokes: s.strokes
            )
        }

        let format: GameFormat
        switch round.gameType {
        case .strokePlay: format = .strokePlay
        case .matchPlay:  format = .matchPlay
        case .skins:      format = .skins
        }

        self.init(
            course: course,
            players: players,
            scores: scores,
            useHandicaps: round.useHandicaps,
            gameFormat: format
        )
    }
}
