//
//  GSPNoticications.swift
//  GolfScorePro
//
//  Created by Greg Booth on 2/27/26.
//
// MARK: - LiveRoundView refactor - PRE-CLAUDE 3/2/26
import Foundation

extension Notification.Name {
    static let gspDismissToHomeFromFinishRound = Notification.Name("gspDismissToHomeFromFinishRound")
    
    // Legacy kept temporarily for safety — remove after you validate everything.
    // static let gspDismissRoundSetupToHome = Notification.Name("gspDismissRoundSetupToHome")
}
