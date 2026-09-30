//
//  LanguageManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.09.2026.
//

import Foundation

@MainActor
protocol LanguageManaging: AnyObject {
    var language: AppLanguage { get }
    var locale: Locale { get }
    var menuOptions: [(AppLanguage, String)] { get }

    /// Resolves a localized string for the currently active language.
    ///
    /// `nonisolated` because `L10n` resolves strings from any thread (e.g. error
    /// descriptions). Reading it from a SwiftUI view's body observes language
    /// changes, so texts refresh in place without recreating views.
    nonisolated func localizedString(_ key: String) -> String

    func setLanguage(_ language: AppLanguage)
}
