//
//  AppSettings.swift
//  GolfScorePro
//
//  Created by Greg Booth on 3/4/26.
//

import SwiftUI
import Combine

final class AppSettings: ObservableObject {
    // Default true for outdoor sunlight readability
    @AppStorage("highContrastMode") var highContrastMode: Bool = true

    // Motion-driven “liquid glass” feel
    @AppStorage("motionGlassEnabled") var motionGlassEnabled: Bool = true

    // Optional calmer mode
    @AppStorage("reducedMotionGlass") var reducedMotionGlass: Bool = false
}
