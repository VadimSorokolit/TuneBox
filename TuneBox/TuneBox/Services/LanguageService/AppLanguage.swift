//
//  AppLanguage.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.09.2026.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case system
    case english = "en"
    case german = "de"
    case spanish = "es"
    case french = "fr"
    case italian = "it"
    case polish = "pl"
    case ukrainian = "uk"

    var id: Self { self }

    static let supportedCodes = allCases.compactMap(\.localeIdentifier)
    static let fallbackCode = "en"

    /// Menu order: System first, then A–Z by native language name.
    static var menuOrder: [AppLanguage] {
        let localized = allCases.filter { $0 != .system }
            .sorted {
                $0.nativeTitle.localizedStandardCompare($1.nativeTitle) == .orderedAscending
            }

        return [.system] + localized
    }

    var localeIdentifier: String? {
        switch self {
            case .system:
                nil

            case .english, .german, .spanish, .french, .italian, .polish, .ukrainian:
                rawValue
        }
    }

    /// Code used to load `.lproj` strings.
    /// System → best match from device preferred languages among supported codes;
    /// if none match → English. Never keeps a previously forced app language.
    var resolvedCode: String {
        switch self {
            case .system:
                Self.resolveSystemCode()

            case .english, .german, .spanish, .french, .italian, .polish, .ukrainian:
                rawValue
        }
    }

    /// Native names stay fixed so users can find their language in any UI locale.
    var nativeTitle: String {
        switch self {
            case .system:
                ""

            case .english:
                "English"

            case .german:
                "Deutsch"

            case .spanish:
                "Español"

            case .french:
                "Français"

            case .italian:
                "Italiano"

            case .polish:
                "Polski"

            case .ukrainian:
                "Українська"
        }
    }

    var menuTitle: String {
        switch self {
            case .system:
                L10n.Settings.languageSystem

            case .english, .german, .spanish, .french, .italian, .polish, .ukrainian:
                nativeTitle
        }
    }

    // MARK: - Methods. Private

    private static func resolveSystemCode() -> String {
        for preferred in Locale.preferredLanguages {
            let preferredLocale = Locale(identifier: preferred)
            let languageCode = preferredLocale.language.languageCode?.identifier
                ?? String(preferred.prefix(2))

            if supportedCodes.contains(languageCode) {
                return languageCode
            }
        }

        if let matched = Bundle.main.preferredLocalizations.first(
            where: { supportedCodes.contains($0) }
        ) {
            return matched
        }

        return fallbackCode
    }
}
