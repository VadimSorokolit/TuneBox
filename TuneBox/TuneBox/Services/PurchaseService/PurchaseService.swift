//
//  PurchaseService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.08.2026.
//

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class PurchaseService: PurchaseServicing {

    // MARK: - Properties. Public

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs = Set<String>()
    private(set) var isLoading = false
    private(set) var error: String?

    // MARK: - Initializer

    init(entitlementService: EntitlementServicing) {
        self.entitlementService = entitlementService
        self.updatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
    }

    // MARK: - Deinitializer

    deinit {
        self.updatesTask?.cancel()
    }

    // MARK: - Methods. Public

    func start() async {
//        await self.loadProducts()
//        await self.updatePurchasedProducts()
    }

    func purchase(_ product: Product) async {
        self.error = nil

        do {
            let result = try await product.purchase()

            switch result {
                case .success(.verified(let transaction)):
                    await transaction.finish()
                    await self.updatePurchasedProducts()

                case .success(.unverified(_, let error)):
                    self.error = error.localizedDescription

                case .pending:
                    break

                case .userCancelled:
                    break

                @unknown default:
                    break
            }
        } catch {
            self.error = error.localizedDescription
            AppLogger.app.warning("Purchase failed: \(error.localizedDescription)")
        }
    }

    func restorePurchases() async {
        self.error = nil

        do {
            try await AppStore.sync()
            await self.updatePurchasedProducts()
        } catch {
            self.error = error.localizedDescription
            AppLogger.app.warning("Restore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Properties. Private

    private enum ProductID {
        static let monthly = "com.TuneBox.premium.monthly"
        static let lifetime = "com.TuneBox.premium.lifetime"
        static let all = [monthly, lifetime]
    }

    private let entitlementService: EntitlementServicing
    private var productsLoaded = false
    @ObservationIgnored
    private nonisolated(unsafe) var updatesTask: Task<Void, Never>?

    // MARK: - Methods. Private

    private func loadProducts() async {
        guard self.productsLoaded.isFalse else { return }

        self.isLoading = true
        defer { self.isLoading = false }

        do {
            self.products = try await Product.products(for: ProductID.all)
                .sorted { $0.price < $1.price }
            self.productsLoaded = true
        } catch {
            self.error = error.localizedDescription
            AppLogger.app.warning("Failed to load products: \(error.localizedDescription)")
        }
    }

    private func updatePurchasedProducts() async {
        var activeProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.revocationDate == nil {
                activeProductIDs.insert(transaction.productID)
            }
        }

        self.purchasedProductIDs = activeProductIDs
        self.entitlementService.setHasPremium(activeProductIDs.isNotEmpty)
    }

    private func observeTransactionUpdates() async {
        for await _ in Transaction.updates {
            await self.updatePurchasedProducts()
        }
    }
}
