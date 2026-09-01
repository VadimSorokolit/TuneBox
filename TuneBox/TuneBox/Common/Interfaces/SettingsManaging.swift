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
    var paywallStatusMessage: String { get }
    var paywallHeaderTitle: String { get }
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
    func presentPaywall()
    func dismissPaywall()
    func openTerms()
    func openPrivacy()

    #if DEBUG
    var localTrialStatus: LocalTrialStatus? { get }

    func debugExpireTrial()
    func debugResetTrial()
    #endif
}
