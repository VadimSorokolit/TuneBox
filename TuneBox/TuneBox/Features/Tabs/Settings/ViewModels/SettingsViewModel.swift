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

    var purchasedProductIDs: Set<String> {
        self.purchaseService.purchasedProductIDs
    }

    var isPaywallPresented = false

    var hasPremium: Bool {
        self.entitlementService.hasPremium
    }

    var products: [Product] {
        self.purchaseService.products
    }

    var isLoading: Bool {
        self.purchaseService.isLoading
    }

    var error: String? {
        self.purchaseService.error
    }

    // MARK: - Initializer

    init() {
        Task { [weak self] in
            await self?.purchaseService.start()
        }
    }

    // MARK: - Methods. Public

    func purchase(_ product: Product) async {
        await self.purchaseService.purchase(product)
    }

    func restorePurchases() async {
        await self.purchaseService.restorePurchases()
    }

    // MARK: - Properties. Private

    @ObservationIgnored
    @Injected private var purchaseService: PurchaseServicing

    @ObservationIgnored
    @Injected private var entitlementService: EntitlementServicing
}
