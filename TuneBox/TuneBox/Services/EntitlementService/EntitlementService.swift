//
//  EntitlementService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.08.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class EntitlementService: EntitlementServicing {

    // MARK: - Properties. Public

    private(set) var hasPremium: Bool = false

    // MARK: - Initializer

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
//      self.hasPremium = userDefaults.bool(forKey: Constants.userDefaultsKey)
        self.hasPremium = true
    }

    // MARK: - Methods. Public

    func setHasPremium(_ value: Bool) {
        guard self.hasPremium != value else { return }

        self.hasPremium = value
        self.userDefaults.set(value, forKey: Constants.userDefaultsKey)
    }

    // MARK: - Properties. Private

    private let userDefaults: UserDefaults

    private enum Constants {
        static let userDefaultsKey = "UserDefaultsHasPremiumKey"
    }
}
