//
//  PaywallView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.08.2026.
//

import Resolver
import StoreKit
import SwiftUI

struct PaywallView: View {

    // MARK: - Main Body

    var body: some View {
        ContentView(settingsVM: settingsVM)
    }

    // MARK: - Properties. Private

    @Injected private var settingsVM: SettingsManaging

    // MARK: - Objects. Private

    private struct ContentView: View {

        // MARK: - Properties. Public

        let settingsVM: SettingsManaging

        // MARK: - Main Body

        var body: some View {
            VStack(spacing: 0) {
                header
                    .padding(.top, 20)

                purchaseOptions
                    .padding(.top, 28)

                Spacer(minLength: 16)

                footerButtons
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(
                .regular.tint(.gray.opacity(0.35)),
                in: .rect(cornerRadius: 28)
            )
            .ignoresSafeArea()
            .task {
                await settingsVM.preparePaywall()
                await refreshStoreIntroEligibility()
            }
        }

        // MARK: - Properties. Private

        @Environment(\.themeManager) private var theme
        @Environment(\.dismiss) private var dismiss
        @State private var purchasingProductID: String?
        @State private var isEligibleForStoreIntro = false

        private var lifetimeProduct: Product? {
            settingsVM.products.first { $0.id == ProductID.lifetime }
        }

        private var monthlyProduct: Product? {
            settingsVM.products.first { $0.id == ProductID.monthly }
        }

        // MARK: - Subviews. Private

        private var header: some View {
            VStack(spacing: 10) {
                appIcon

                Text(settingsVM.paywallStatusMessage)
                    .font(.satoshi.regular.size(13))
                    .foregroundStyle(theme.tokens.secondaryText)
                    .multilineTextAlignment(.center)
                    .opacity(settingsVM.isLoading ? 0.4 : 1)

                Text(settingsVM.paywallHeaderTitle)
                    .font(.satoshi.bold.size(28))
                    .foregroundStyle(theme.tokens.primaryText)
                    .multilineTextAlignment(.center)
            }
        }

        private var appIcon: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.tokens.accent)
                    .frame(width: 44, height: 44)

                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }

        private func monthlySubscriptionSubtitle(for product: Product) -> String {
            if isEligibleForStoreIntro,
               let offer = product.subscription?.introductoryOffer,
               offer.paymentMode == .freeTrial {
                let period = Self.formattedSubscriptionPeriod(offer.period)
                return "\(period) free trial via subscription, then unlocks all playback functionality."
            }

            return "Unlocks all playback functionality."
        }

        private func refreshStoreIntroEligibility() async {
            guard let subscription = monthlyProduct?.subscription else {
                isEligibleForStoreIntro = false
                return
            }

            isEligibleForStoreIntro = await subscription.isEligibleForIntroOffer
        }

        private static func formattedSubscriptionPeriod(_ period: Product.SubscriptionPeriod) -> String {
            switch period.unit {
                case .day:
                    period.value == 1 ? "1 day" : "\(period.value) days"
                case .week:
                    period.value == 1 ? "1 week" : "\(period.value) weeks"
                case .month:
                    period.value == 1 ? "1 month" : "\(period.value) months"
                case .year:
                    period.value == 1 ? "1 year" : "\(period.value) years"
                @unknown default:
                    "trial"
            }
        }

        private var purchaseOptions: some View {
            VStack(spacing: 24) {
                if let lifetimeProduct {
                    purchaseRow(
                        title: "Lifetime License",
                        subtitle: "Unlocks all playback functionality.",
                        price: lifetimeProduct.displayPrice,
                        periodLabel: nil,
                        product: lifetimeProduct
                    )
                }

                if let monthlyProduct {
                    purchaseRow(
                        title: "Monthly Subscription",
                        subtitle: monthlySubscriptionSubtitle(for: monthlyProduct),
                        price: monthlyProduct.displayPrice,
                        periodLabel: "Every Month",
                        product: monthlyProduct
                    )
                }

                if settingsVM.isLoading && settingsVM.products.isEmpty {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
        }

        private func purchaseRow(
            title: String,
            subtitle: String,
            price: String,
            periodLabel: String?,
            product: Product
        ) -> some View {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.satoshi.bold.size(17))
                        .foregroundStyle(theme.tokens.primaryText)

                    Text(subtitle)
                        .font(.satoshi.regular.size(13))
                        .foregroundStyle(theme.tokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(spacing: 4) {
                    priceButton(price: price, product: product)

                    if let periodLabel {
                        Text(periodLabel)
                            .font(.satoshi.regular.size(11))
                            .foregroundStyle(theme.tokens.secondaryText)
                    }
                }
            }
        }

        private func priceButton(price: String, product: Product) -> some View {
            let isPurchasing = purchasingProductID == product.id

            return Button(action: {
                Task {
                    purchasingProductID = product.id
                    let didPurchase = await settingsVM.purchase(product)
                    purchasingProductID = nil

                    guard didPurchase else { return }

                    settingsVM.dismissPaywall()
                    dismiss()
                }
            }, label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .tint(theme.tokens.accent)
                    } else {
                        Text(price)
                            .font(.satoshi.bold.size(15))
                            .foregroundStyle(theme.tokens.accent)
                    }
                }
                .frame(width: 55)
            })
            .buttonStyle(.glass)
            .disabled(isPurchasing || settingsVM.isLoading)
        }

        private var footerButtons: some View {
            HStack {
                footerButton(
                    action: settingsVM.restorePurchase,
                    title: "Restore"
                )

                Spacer()

                footerButton(
                    action: settingsVM.openTerms,
                    title: "Terms"
                )

                Spacer()

                footerButton(
                    action: settingsVM.openPrivacy,
                    title: "Privacy"
                )
            }
        }

        private func footerButton(
            action: @escaping () -> Void,
            title: String
        ) -> some View {
            Button(action: {
                action()
            }, label: {
                Text(title)
                    .font(.satoshi.medium.size(14))
                    .foregroundStyle(theme.tokens.primaryText)
                    .frame(width: 60)
                    .padding(.vertical, 4)
            })
            .buttonStyle(.glass)
        }
    }

}

#Preview {
    PaywallView()
        .environment(\.themeManager, ThemeManager())
}
