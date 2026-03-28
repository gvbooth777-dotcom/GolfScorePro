//
//  GolfScoreProApp.swift
//  GolfScorePro
//
//  Created by Greg Booth on 12/2/25.
//
// 2/17/26 - You want one global place so the entire app follows Apple’s system tint behavior automatically.


import SwiftUI
import SwiftData

@main
struct GolfScoreProApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
            /// You want one global place so the entire app follows Apple’s system tint behavior automatically.
                .tint(.accentColor)
        }
        .modelContainer(for: [Course.self, Round.self, Player.self, Score.self])
    }
}




