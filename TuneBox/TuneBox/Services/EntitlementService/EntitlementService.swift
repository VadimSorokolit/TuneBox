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
    private(set) var localTrialStatus: LocalTrialStatus?
    private(set) var paywallStatusMessage: String = "Unlock full playback access"

    // MARK: - Initializer

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hasPurchasedPremium = userDefaults.bool(forKey: Constants.hasPurchasedPremiumKey)
        self.refreshAccessState()
    }

    // MARK: - Methods. Public

    func bootstrapLocalTrialIfNeeded() {
        if self.userDefaults.object(forKey: Constants.trialStartDateKey) == nil {
            self.userDefaults.set(Date(), forKey: Constants.trialStartDateKey)
        }

        self.refreshAccessState()
    }

    func refreshAccessState() {
        self.localTrialStatus = self.makeLocalTrialStatus()
        self.hasPremium = self.hasPurchasedPremium || (self.localTrialStatus?.isActive ?? false)
        self.paywallStatusMessage = self.makePaywallStatusMessage()
    }

    func setHasPremium(_ value: Bool) {
        guard self.hasPurchasedPremium != value else {
            self.refreshAccessState()
            return
        }

        self.hasPurchasedPremium = value
        self.userDefaults.set(value, forKey: Constants.hasPurchasedPremiumKey)
        self.refreshAccessState()
    }

    // MARK: - Properties. Private

    private var hasPurchasedPremium: Bool
    private let userDefaults: UserDefaults

    private enum Constants {
        static let trialStartDateKey = "tunebox.trialStartDate"
        static let hasPurchasedPremiumKey = "UserDefaultsHasPremiumKey"
    }

    // MARK: - Methods. Private

    private func makeLocalTrialStatus() -> LocalTrialStatus? {
        guard let trialStartDate = self.userDefaults.object(forKey: Constants.trialStartDateKey) as? Date else {
            return nil
        }

        let trialEndDate = trialStartDate.addingTimeInterval(TrialConfiguration.duration)

        if Date() < trialEndDate {
            return .active(until: trialEndDate)
        }

        return .expired(since: trialEndDate)
    }

    private func makePaywallStatusMessage() -> String {
        switch self.localTrialStatus {
            case .active(until: let endDate):
                return "Your trial ends on \(Self.formatted(endDate))"

            case .expired(since: let endDate):
                return "Your trial ended on \(Self.formatted(endDate))"

            case nil:
                return "Unlock full playback access"
        }
    }

    private static func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    #if DEBUG

    func debugExpireTrial() {
        let expiredStartDate = Date().addingTimeInterval(-(TrialConfiguration.duration + 86_400))
        self.userDefaults.set(expiredStartDate, forKey: Constants.trialStartDateKey)
        self.hasPurchasedPremium = false
        self.userDefaults.set(false, forKey: Constants.hasPurchasedPremiumKey)
        self.refreshAccessState()
    }

    func debugResetTrial() {
        self.userDefaults.removeObject(forKey: Constants.trialStartDateKey)
        self.hasPurchasedPremium = false
        self.userDefaults.set(false, forKey: Constants.hasPurchasedPremiumKey)
        self.bootstrapLocalTrialIfNeeded()
    }

    #endif
}
