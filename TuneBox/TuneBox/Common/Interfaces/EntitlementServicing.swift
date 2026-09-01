//
//  EntitlementServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.08.2026.
//

import Foundation

@MainActor
protocol EntitlementServicing: AnyObject {
    var hasPremium: Bool { get }
    var localTrialStatus: LocalTrialStatus? { get }
    var paywallStatusMessage: String { get }
    var subscriptionExpirationDate: Date? { get }

    func bootstrapLocalTrialIfNeeded()
    func refreshAccessState()
    func updatePurchasedProducts(
        activeProductIDs: Set<String>,
        subscriptionExpirationDate: Date?,
        allowClearing: Bool
    )
    func isPurchaseStatusReady(for productID: String) -> Bool

    #if DEBUG
    func debugExpireTrial()
    func debugResetTrial()
    #endif
}
