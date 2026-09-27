//
//  LanguageService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.09.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class LanguageService: LanguageServicing {

    // MARK: - Properties. Public

    enum Constants {
        static let userDefaultsLanguageKey = "tuneboxLanguage"
    }

    private(set) var selectedLanguage: AppLanguage = .system

    var resolvedCode: String {
        self.selectedLanguage.resolvedCode
    }

    var locale: Locale {
        Locale(identifier: self.resolvedCode)
    }

    // MARK: - Initializer

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let raw = userDefaults.string(forKey: Constants.userDefaultsLanguageKey),
           let saved = AppLanguage(rawValue: raw) {
            self.selectedLanguage = saved
        }
    }

    // MARK: - Methods. Public

    func setLanguage(_ language: AppLanguage) {
        guard self.selectedLanguage != language else { return }

        self.selectedLanguage = language
        self.userDefaults.set(
            language.rawValue,
            forKey: Constants.userDefaultsLanguageKey
        )
    }

    // MARK: - Properties. Private

    @ObservationIgnored
    private let userDefaults: UserDefaults
}
