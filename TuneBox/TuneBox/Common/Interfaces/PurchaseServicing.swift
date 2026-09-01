//
//  PurchaseServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.08.2026.
//

import Foundation
import StoreKit

@MainActor
protocol PurchaseServicing: LoadStateManaging {
    var products: [Product] { get }
    var purchasedProductIDs: Set<String> { get }

    func start() async
    func preparePaywall() async
    func purchase(_ product: Product) async -> Bool
    func restorePurchases() async
}
