//
//  GSPDesign.swift
//  GolfScorePro
//
//  Refactor: 2026-02-16 14:xx PT
//
//  What you should see now:
//  - A single shared typography layer (GSPTextStyle + helpers).
//  - Apple-native system typography (NO rounded design).
//  - Fixes “Invalid redeclaration of GSPTextStyle” across the project.
//  - Fixes “Cannot infer contextual base for .sheetTitle” when used in views.
//

import SwiftUI

/// Single source of truth for app typography roles.
enum GSPTextStyle {
    case screenTitle
    case screenSubtitle

    case sectionTitle

    case rowTitle
    case rowSubtitle
    case rowTrailing

    case pillTitle
    case pillSubtitle

    case sheetTitle
    case sheetAction
}

enum GSPDesign {

    // MARK: - Typography

    static func font(_ style: GSPTextStyle) -> Font {
        switch style {
        case .screenTitle:
            // Big, Apple-ish header (Notes-like, but not rounded 34->38)
            return .system(size: 38, weight: .bold, design: .default)

        case .screenSubtitle:
            return .system(size: 17, weight: .semibold, design: .default)

        case .sectionTitle:
            return .system(size: 17, weight: .semibold, design: .default)

        case .rowTitle:
            return .system(size: 17, weight: .semibold, design: .default)

        case .rowSubtitle:
            return .system(size: 15, weight: .regular, design: .default)

        case .rowTrailing:
            return .system(size: 15, weight: .semibold, design: .default)

        case .pillTitle:
            return .system(size: 20, weight: .semibold, design: .default)

        case .pillSubtitle:
            return .system(size: 15, weight: .semibold, design: .default)

        case .sheetTitle:
            return .system(size: 17, weight: .semibold, design: .default)

        case .sheetAction:
            return .system(size: 17, weight: .semibold, design: .default)
        }
    }
}

// MARK: - Convenience modifiers

extension View {
    func gspFont(_ style: GSPTextStyle) -> some View {
        self.font(GSPDesign.font(style))
    }
}
