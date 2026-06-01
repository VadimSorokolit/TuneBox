//
//  AppTheme.swift
//  TuneBox
//
//  Created by Nintendo on 01.06.2026.
//

import SwiftUI

enum ThemePreset: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String {
        rawValue
    }

    var displayName: String {
        rawValue.capitalized
    }
}

struct ThemeTokens {
    let background: Color
    let cardBackground: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let backgroundImageName: String?
}

extension ThemeTokens {

    static let light = Self(
        background: .white,
        cardBackground: Color(red: 0.96, green: 0.96, blue: 0.98),
        primaryText: .black,
        secondaryText: .gray,
        accent: .blue,
        backgroundImageName: "bg-pattern-light"
    )

    static let dark = Self(
        background: Color(red: 0.05, green: 0.05, blue: 0.08),
        cardBackground: Color(red: 0.12, green: 0.12, blue: 0.16),
        primaryText: .white,
        secondaryText: Color.gray.opacity(0.7),
        accent: Color(red: 0.3, green: 0.6, blue: 1.0),
        backgroundImageName: "bg-pattern-dark"
    )
}
