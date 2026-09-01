//
//  SettingsViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.06.2026.
//

import Foundation
import Observation
import StoreKit
import Resolver

@MainActor
@Observable
final class SettingsViewModel: SettingsManaging {

    // MARK: - Properties. Public

    private(set) var purchasedProductIDs = Set<String>()
    var isPaywallPresented = false
    private(set) var hasPremium: Bool = false
    private(set) var paywallStatusMessage: String = "Unlock full playback access"
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var error: String?

    var paywallHeaderTitle: String {
        self.purchasedProductIDs.isNotEmpty
        ? self.hasLifetimePurchase
        ? "Lifetime Plan"
        : "TuneBox Premium"
        : "Purchase TuneBox"
    }

    var hasLifetimePurchase: Bool {
        self.purchasedProductIDs.contains(ProductID.lifetime)
    }

    var hasMonthlyPurchase: Bool {
        self.purchasedProductIDs.contains(ProductID.monthly)
    }

    // MARK: - Initializer

    init() {}

    // MARK: - Methods. Public

    func start() async {
        await self.purchaseService.start()
        self.syncFromServices()
    }

    func preparePaywall() async {
        await self.purchaseService.preparePaywall()
        self.syncFromServices()
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        let didPurchase = await self.purchaseService.purchase(product)
        self.syncFromServices()
        return didPurchase
    }

    func restorePurchases() async {
        await self.purchaseService.restorePurchases()
        self.syncFromServices()
    }

    func refreshAccessState() {
        self.entitlementService.refreshAccessState()
        self.syncFromServices()
    }

    func restorePurchase() {
        Task {
            await self.restorePurchases()
        }
    }

    func presentPaywall() {
        self.isPaywallPresented = true
    }

    func dismissPaywall() {
        self.isPaywallPresented = false
    }

    func openTerms() {}

    func openPrivacy() {}

    #if DEBUG

    var localTrialStatus: LocalTrialStatus? {
        self.entitlementService.localTrialStatus
    }

    func debugExpireTrial() {
        self.entitlementService.debugExpireTrial()
        self.syncFromServices()
    }

    func debugResetTrial() {
        self.entitlementService.debugResetTrial()
        self.syncFromServices()
    }

    #endif

    // MARK: - Properties. Private

    @ObservationIgnored
    @Injected private var purchaseService: PurchaseServicing

    @ObservationIgnored
    @Injected private var entitlementService: EntitlementServicing

    // MARK: - Methods. Private

    private func syncFromServices() {
        self.products = self.purchaseService.products
        self.purchasedProductIDs = self.purchaseService.purchasedProductIDs
        self.isLoading = self.purchaseService.isLoading
        self.error = self.purchaseService.error
        self.hasPremium = self.entitlementService.hasPremium
        self.paywallStatusMessage = self.entitlementService.paywallStatusMessage
    }
}
