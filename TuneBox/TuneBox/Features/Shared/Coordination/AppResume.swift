//
//  AppResume.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 29.09.2026.
//

import Foundation

/// Shared “quick reopen” window for default-tab restore after backgrounding.
enum AppResume {
    static let quickThreshold: TimeInterval = 5

    static func markBackgrounded(
        defaults: UserDefaults = .standard
    ) {
        defaults.set(Date.now, forKey: GlobalConstants.UserDefaultsKey.lastBackgroundedAt)
    }

    static func isQuickResume(
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard let backgroundedAt = defaults.object(
            forKey: GlobalConstants.UserDefaultsKey.lastBackgroundedAt
        ) as? Date else {
            return false
        }

        return Date.now.timeIntervalSince(backgroundedAt) < quickThreshold
    }
}
