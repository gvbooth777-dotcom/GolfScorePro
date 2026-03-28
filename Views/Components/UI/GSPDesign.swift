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
        case .screenTitle:    return .largeTitle.bold()
        case .screenSubtitle: return .subheadline
        case .sectionTitle:   return .caption.weight(.semibold)
        case .rowTitle:       return .body.weight(.semibold)
        case .rowSubtitle:    return .subheadline
        case .rowTrailing:    return .subheadline.weight(.semibold)
        case .pillTitle:      return .title2.weight(.semibold)
        case .pillSubtitle:   return .subheadline
        case .sheetTitle:     return .title3.weight(.semibold)
        case .sheetAction:    return .headline
        }
    }
}

// MARK: - Convenience modifiers

extension View {
    func gspFont(_ style: GSPTextStyle) -> some View {
        self.font(GSPDesign.font(style))
    }
}
