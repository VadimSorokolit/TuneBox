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
    var isPaywallPresented: Bool { get set }
    var products: [Product] { get }
    var purchasedProductIDs: Set<String> { get }

    func purchase(_ product: Product) async
    func restorePurchases() async
    func restorePurchase()
    func openTerms()
    func openPrivacy()
}
