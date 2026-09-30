//
//  LanguageViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.09.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class LanguageViewModel: LanguageManaging {

    // MARK: - Properties. Public

    private(set) var language: AppLanguage = .system

    var locale: Locale {
        self.languageService.locale
    }

    var menuOptions: [(AppLanguage, String)] {
        AppLanguage.menuOrder.map { ($0, $0.menuTitle) }
    }

    // MARK: - Initializer

    init(languageService: LanguageServicing) {
        self.languageService = languageService
        self.language = languageService.selectedLanguage
        self.cachedBundle = Self.resolveBundle(for: languageService.selectedLanguage)
    }

    // MARK: - Methods. Public

    nonisolated func localizedString(_ key: String) -> String {
        if Thread.isMainThread {
            MainActor.assumeIsolated { _ = self.localizationVersion }
        }

        let bundle = self.lock.withLock { self.cachedBundle }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }

        self.languageService.setLanguage(language)
        self.language = self.languageService.selectedLanguage

        // Refresh localized texts everywhere in place, without recreating views.
        let bundle = Self.resolveBundle(for: self.language)
        self.lock.withLock { self.cachedBundle = bundle }
        self.localizationVersion &+= 1

        NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
    }

    // MARK: - Properties. Private

    /// Bumped on every language change. Observed via `localizedString(_:)` so live
    /// SwiftUI views re-evaluate their bodies and pick up new texts.
    private var localizationVersion = 0

    @ObservationIgnored
    private let languageService: LanguageServicing

    @ObservationIgnored
    nonisolated private let lock = NSLock()

    @ObservationIgnored
    nonisolated(unsafe) private var cachedBundle: Bundle

    // MARK: - Methods. Private

    private static func resolveBundle(for language: AppLanguage) -> Bundle {
        let code = language.resolvedCode

        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        if let fallbackPath = Bundle.main.path(
            forResource: AppLanguage.fallbackCode,
            ofType: "lproj"
        ),
           let fallbackBundle = Bundle(path: fallbackPath) {
            return fallbackBundle
        }

        return .main
    }
}
