//
//  SettingsManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.06.2026.
//

import Foundation
import StoreKit

@MainActor
protocol SettingsManaging: LoadStateManaging {
    var hasPremium: Bool { get }
    var hasLifetimePurchase: Bool { get }
    var hasMonthlyPurchase: Bool { get }
    var paywallStatusMessage: String { get }
    var paywallHeaderTitle: String { get }
    var marketingVersion: String { get }
    var isPaywallPresented: Bool { get set }
    var products: [Product] { get }
    var purchasedProductIDs: Set<String> { get }

    func start() async
    func preparePaywall() async
    @discardableResult
    func purchase(_ product: Product) async -> Bool
    func refreshAccessState()
    func restorePurchases() async
    func restorePurchase()
    func dismissError()
    func presentPaywall()
    func dismissPaywall()
    var shareURL: URL? { get }
    var termsOfUseURL: URL? { get }
    var privacyPolicyURL: URL? { get }
    var isSleepTimerActive: Bool { get }
    var sleepTimerTrailingText: String { get }
    /// Remaining fraction `1 → 0` while the sleep timer runs; `0` when inactive.
    var sleepTimerProgress: Double { get }
    /// Compact countdown for the header control (fits inside a 44pt circle).
    var sleepTimerHeaderText: String { get }
    func startSleepTimer(hours: Int, minutes: Int)
    func cancelSleepTimer()
    func submitFeedback(
        rating: Int,
        ratingLabel: String,
        emoji: String,
        comment: String
    ) async throws
}
