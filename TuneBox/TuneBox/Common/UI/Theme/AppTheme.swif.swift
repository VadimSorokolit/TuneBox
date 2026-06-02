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
    let appBackground: Color
    let tabBarBackground: Color
    let tabIconActive: Color
    let tabIconInactive: Color
    let cardBackground: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let backgroundImageName: String?
}

extension ThemeTokens {

    static let light = Self(
        appBackground: Color(hex: 0xF7F7F7),
        tabBarBackground: Color(hex: 0xEFEFEF),
        tabIconActive: Color(hex: 0x007AFF),
        tabIconInactive: Color.black.opacity(0.45),
        cardBackground: Color(red: 0.96, green: 0.96, blue: 0.98),
        primaryText: .black,
        secondaryText: .gray,
        accent: Color(hex: 0x5E9C76),
        backgroundImageName: nil
    )

    static let dark = Self(
        appBackground: Color(hex: 0x121212),
        tabBarBackground: Color(hex: 0x0A0A0A),
        tabIconActive: Color(hex: 0x4F6EF7),
        tabIconInactive: Color.white.opacity(0.45),
        cardBackground: Color(red: 0.12, green: 0.12, blue: 0.16),
        primaryText: .white,
        secondaryText: Color.gray.opacity(0.7),
        accent: Color(hex: 0x5E9C76),
        backgroundImageName: nil
    )

}
