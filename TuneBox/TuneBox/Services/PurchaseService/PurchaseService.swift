//
//  PurchaseService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.08.2026.
//

import Foundation
import Observation
import StoreKit

enum ProductID {
    static let monthly = "com.TuneBox.premium.monthly"
    static let lifetime = "com.TuneBox.premium.lifetime"
    static let all = [monthly, lifetime]
}

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
        await self.runInitialization()
    }

    func preparePaywall() async {
        await self.runInitialization()

        if self.products.isEmpty {
            self.productsLoaded = false
            await self.loadProducts()
        }

        await self.syncPurchaseState()
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        self.error = nil

        do {
            let result = try await product.purchase()

            switch result {
                case .success(.verified(let transaction)):
                    await self.applyPurchaseState(from: transaction)
                    await transaction.finish()
                    await self.syncPurchaseState(expecting: product.id, replaceExisting: false)
                    return self.purchasedProductIDs.contains(product.id)

                case .success(.unverified(_, let error)):
                    self.error = error.localizedDescription
                    return false

                case .pending:
                    return false

                case .userCancelled:
                    return false

                @unknown default:
                    return false
            }
        } catch {
            self.error = error.localizedDescription
            AppLogger.app.warning("Purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    func restorePurchases() async {
        self.error = nil

        do {
            try await AppStore.sync()
            await self.syncPurchaseState(replaceExisting: true)
        } catch {
            self.error = error.localizedDescription
            AppLogger.app.warning("Restore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Properties. Private

    private let entitlementService: EntitlementServicing
    private var productsLoaded = false
    private var initializationTask: Task<Void, Never>?
    @ObservationIgnored
    private nonisolated(unsafe) var updatesTask: Task<Void, Never>?

    // MARK: - Methods. Private

    private func runInitialization() async {
        if let initializationTask {
            await initializationTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }

            self.entitlementService.bootstrapLocalTrialIfNeeded()
            await self.loadProducts()
            await self.syncPurchaseState()
        }

        self.initializationTask = task
        await task.value
    }

    private func loadProducts() async {
        guard self.productsLoaded.isFalse else { return }

        self.isLoading = true
        defer { self.isLoading = false }

        do {
            for attempt in 0..<3 {
                let loadedProducts = try await Product.products(for: ProductID.all)
                    .sorted { $0.price < $1.price }

                if loadedProducts.isNotEmpty {
                    self.products = loadedProducts
                    self.productsLoaded = true
                    return
                }

                guard attempt < 2 else {
                    self.products = loadedProducts
                    return
                }

                try await Task.sleep(for: .milliseconds(500 * (attempt + 1)))
            }
        } catch {
            self.error = error.localizedDescription
            AppLogger.app.warning("Failed to load products: \(error.localizedDescription)")
        }
    }

    private func syncPurchaseState(
        expecting expectedProductID: String? = nil,
        replaceExisting: Bool = false
    ) async {
        self.isLoading = true
        defer { self.isLoading = false }

        let maxAttempts = expectedProductID == nil ? 1 : 5

        for attempt in 0..<maxAttempts {
            await self.applyPurchaseStateFromStore(replaceExisting: replaceExisting)

            if let expectedProductID,
               self.entitlementService.isPurchaseStatusReady(for: expectedProductID) {
                return
            }

            if expectedProductID == nil {
                return
            }

            guard attempt < maxAttempts - 1 else { break }

            try? await Task.sleep(for: .milliseconds(300 * (attempt + 1)))
        }
    }

    private func applyPurchaseState(from transaction: StoreKit.Transaction) async {
        guard transaction.revocationDate == nil else { return }

        var activeProductIDs = self.purchasedProductIDs
        activeProductIDs.insert(transaction.productID)

        var subscriptionExpirationDate = transaction.expirationDate
            ?? self.entitlementService.subscriptionExpirationDate

        if subscriptionExpirationDate == nil,
           transaction.productID == ProductID.monthly {
            subscriptionExpirationDate = await self.fetchSubscriptionExpirationDate()
        }

        self.purchasedProductIDs = activeProductIDs
        self.entitlementService.updatePurchasedProducts(
            activeProductIDs: activeProductIDs,
            subscriptionExpirationDate: subscriptionExpirationDate,
            allowClearing: true
        )
    }

    private func applyPurchaseStateFromStore(replaceExisting: Bool) async {
        var storeProductIDs = Set<String>()
        var subscriptionExpirationDate: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            guard transaction.revocationDate == nil else { continue }

            storeProductIDs.insert(transaction.productID)

            if let expirationDate = transaction.expirationDate {
                if subscriptionExpirationDate.map({ expirationDate > $0 }) ?? true {
                    subscriptionExpirationDate = expirationDate
                }
            }
        }

        if storeProductIDs.isEmpty {
            if replaceExisting {
                self.purchasedProductIDs = []
                self.entitlementService.updatePurchasedProducts(
                    activeProductIDs: [],
                    subscriptionExpirationDate: nil,
                    allowClearing: true
                )
            } else if self.purchasedProductIDs.contains(ProductID.monthly),
                      subscriptionExpirationDate == nil {
                subscriptionExpirationDate = await self.fetchSubscriptionExpirationDate()

                if let subscriptionExpirationDate {
                    self.entitlementService.updatePurchasedProducts(
                        activeProductIDs: self.purchasedProductIDs,
                        subscriptionExpirationDate: subscriptionExpirationDate,
                        allowClearing: false
                    )
                }
            }

            return
        }

        let activeProductIDs = replaceExisting
            ? storeProductIDs
            : self.purchasedProductIDs.union(storeProductIDs)

        if subscriptionExpirationDate == nil,
           activeProductIDs.contains(ProductID.monthly) {
            subscriptionExpirationDate = await self.fetchSubscriptionExpirationDate()
                ?? self.entitlementService.subscriptionExpirationDate
        }

        self.purchasedProductIDs = activeProductIDs
        self.entitlementService.updatePurchasedProducts(
            activeProductIDs: activeProductIDs,
            subscriptionExpirationDate: subscriptionExpirationDate,
            allowClearing: replaceExisting
        )
    }

    private func observeTransactionUpdates() async {
        for await _ in Transaction.updates {
            await self.syncPurchaseState()
        }
    }

    private func fetchSubscriptionExpirationDate() async -> Date? {
        guard let product = self.products.first(where: { $0.id == ProductID.monthly }),
              let subscription = product.subscription,
              let statuses = try? await subscription.status else {
            return nil
        }

        var latestExpirationDate: Date?

        for status in statuses {
            guard case .verified(let transaction) = status.transaction else { continue }

            if let expirationDate = transaction.expirationDate {
                if latestExpirationDate.map({ expirationDate > $0 }) ?? true {
                    latestExpirationDate = expirationDate
                }
            }
        }

        return latestExpirationDate
    }
}
