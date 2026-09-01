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
    private(set) var subscriptionExpirationDate: Date?

    // MARK: - Initializer

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hasPurchasedPremium = userDefaults.bool(forKey: Constants.hasPurchasedPremiumKey)
        self.subscriptionExpirationDate = userDefaults.object(forKey: Constants.subscriptionExpirationDateKey) as? Date

        if let storedProductIDs = userDefaults.array(forKey: Constants.purchasedProductIDsKey) as? [String] {
            self.purchasedProductIDs = Set(storedProductIDs)
        }

        self.refreshAccessState()
    }

    func isPurchaseStatusReady(for productID: String) -> Bool {
        guard self.hasPurchasedPremium,
              self.purchasedProductIDs.contains(productID) else {
            return false
        }

        if productID == ProductID.monthly {
            return self.subscriptionExpirationDate != nil
        }

        return true
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

    func updatePurchasedProducts(
        activeProductIDs: Set<String>,
        subscriptionExpirationDate: Date?,
        allowClearing: Bool = true
    ) {
        if activeProductIDs.isEmpty && allowClearing.isFalse {
            if let subscriptionExpirationDate {
                self.subscriptionExpirationDate = subscriptionExpirationDate
                self.persistPurchaseState()
                self.refreshAccessState()
            }

            return
        }

        let hasPurchase = activeProductIDs.isNotEmpty
        var subscriptionExpirationDate = subscriptionExpirationDate

        if subscriptionExpirationDate == nil,
           activeProductIDs.contains(ProductID.monthly),
           let existingExpirationDate = self.subscriptionExpirationDate,
           existingExpirationDate > Date() {
            subscriptionExpirationDate = existingExpirationDate
        }

        if self.hasPurchasedPremium != hasPurchase {
            self.hasPurchasedPremium = hasPurchase
        }

        self.purchasedProductIDs = activeProductIDs
        self.subscriptionExpirationDate = subscriptionExpirationDate
        self.persistPurchaseState()
        self.refreshAccessState()
    }

    // MARK: - Properties. Private

    private var hasPurchasedPremium: Bool
    private var purchasedProductIDs = Set<String>()
    private let userDefaults: UserDefaults

    private enum Constants {
        static let trialStartDateKey = "tunebox.trialStartDate"
        static let hasPurchasedPremiumKey = "UserDefaultsHasPremiumKey"
        static let subscriptionExpirationDateKey = "tunebox.subscriptionExpirationDate"
        static let purchasedProductIDsKey = "tunebox.purchasedProductIDs"
    }

    // MARK: - Methods. Private

    private func persistPurchaseState() {
        self.userDefaults.set(self.hasPurchasedPremium, forKey: Constants.hasPurchasedPremiumKey)

        if let subscriptionExpirationDate = self.subscriptionExpirationDate {
            self.userDefaults.set(subscriptionExpirationDate, forKey: Constants.subscriptionExpirationDateKey)
        } else {
            self.userDefaults.removeObject(forKey: Constants.subscriptionExpirationDateKey)
        }

        self.userDefaults.set(Array(self.purchasedProductIDs), forKey: Constants.purchasedProductIDsKey)
    }

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
        if self.hasPurchasedPremium {
            if self.purchasedProductIDs.contains(ProductID.lifetime) {
                return "Lifetime license active"
            }

            if let subscriptionExpirationDate = self.subscriptionExpirationDate {
                return "Your subscription is active until \(Self.formatted(subscriptionExpirationDate))"
            }

            return "Premium active"
        }

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
        self.purchasedProductIDs = []
        self.subscriptionExpirationDate = nil
        self.persistPurchaseState()
        self.refreshAccessState()
    }

    func debugResetTrial() {
        self.userDefaults.removeObject(forKey: Constants.trialStartDateKey)
        self.hasPurchasedPremium = false
        self.purchasedProductIDs = []
        self.subscriptionExpirationDate = nil
        self.persistPurchaseState()
        self.bootstrapLocalTrialIfNeeded()
    }

    #endif
}
