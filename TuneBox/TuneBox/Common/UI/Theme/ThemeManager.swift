//
//  ThemeManager.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 01.06.2026.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ThemeManager {

    // MARK: - Properties. Public

    enum Constants {
        static let userDefaultsThemeKey: String = "tuneboxTheme"
    }

    private(set) var systemColorScheme: ColorScheme = .light

    private(set) var preset: ThemePreset = .system {
        didSet {
            UserDefaults.standard.set(preset.rawValue, forKey: Constants.userDefaultsThemeKey)
        }
    }

    var tokens: ThemeTokens {
        switch preset {
            case .system:
                return self.systemColorScheme == .dark ? .dark : .light
            case .light:
                return .light
            case .dark:
                return .dark
        }
    }

    var forcedColorScheme: ColorScheme? {
        switch preset {
            case .system:
                nil
            case .light:
                    .light
            case .dark:
                    .dark
        }
    }

    func setPreset(_ preset: ThemePreset) {
        self.preset = preset
    }

    // MARK: - Methods. Public

    func syncSystemScheme(_ scheme: ColorScheme) {
        self.systemColorScheme = scheme
    }

    // MARK: - Initializer

    init() {
        if let raw = UserDefaults.standard.string(forKey: "tuneboxTheme"),
           let saved = ThemePreset(rawValue: raw) {
            self.preset = saved
        }
    }
}
