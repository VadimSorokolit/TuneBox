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
    private(set) var refreshID = UUID()

    var locale: Locale {
        self.languageService.locale
    }

    var menuOptions: [(AppLanguage, String)] {
        AppLanguage.menuOrder.map { ($0, $0.menuTitle) }
    }

    // MARK: - Initializer

    init(languageService: LanguageServicing) {
        self.languageService = languageService
        self.syncFromService()
    }

    // MARK: - Methods. Public

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }

        self.languageService.setLanguage(language)
        self.syncFromService()
        self.refreshID = UUID()
    }

    // MARK: - Properties. Private

    @ObservationIgnored
    private let languageService: LanguageServicing

    // MARK: - Methods. Private

    private func syncFromService() {
        self.language = self.languageService.selectedLanguage
    }
}
