//
//  Course.swift
//  GolfScorePro
//
//  Created by Greg Booth on 12/12/25.
//

import Foundation
import SwiftData

@Model
final class Course {
    var id: UUID
    var name: String
    var totalHoles: Int

    /// Par values, index 0 = hole 1
    var pars: [Int]

    /// Stroke index / handicap ranking, index 0 = hole 1, values 1..9 or 1..18
    var strokeIndex: [Int]

    var createdAt: Date
    var updatedAt: Date

    init(name: String,
         totalHoles: Int = 18,
         pars: [Int]? = nil,
         strokeIndex: [Int]? = nil,
         createdAt: Date = .now,
         updatedAt: Date = .now) {

        let finalPars = pars ?? Array(repeating: 4, count: totalHoles)

        // Default stroke index is 1..N if not provided (not “real”, but safe placeholder)
        let finalStrokeIndex = strokeIndex ?? Array(1...totalHoles)

        self.id = UUID()
        self.name = name
        self.totalHoles = totalHoles
        self.pars = Array(finalPars.prefix(totalHoles))
        self.strokeIndex = Array(finalStrokeIndex.prefix(totalHoles))
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func parForHole(_ hole: Int) -> Int {
        guard hole >= 1, hole <= pars.count else { return 4 }
        return pars[hole - 1]
    }

    func strokeIndexForHole(_ hole: Int) -> Int {
        guard hole >= 1, hole <= strokeIndex.count else { return hole }
        return strokeIndex[hole - 1]
    }
}
