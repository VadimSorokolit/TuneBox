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

                purchaseOptions

                if showsSubscriptionDisclosure {
                    subscriptionDisclosure
                        .padding(.top, 20)
                }

                Spacer(minLength: 16)

                footerButtons
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.tokens.appBackground)
            .glassEffect(
                .regular.tint(sheetGlassTint),
                in: .rect(cornerRadius: 28)
            )
            .presentationBackground(theme.tokens.appBackground)
            .ignoresSafeArea()
            .task {
                await settingsVM.preparePaywall()
            }
            .onChange(of: settingsVM.error) { _, newValue in
                isErrorPresented = newValue != nil
            }
            .alert(L10n.Common.error, isPresented: $isErrorPresented) {
                Button(L10n.Common.okButton, role: .cancel) {
                    settingsVM.dismissError()
                }
            } message: {
                Text(settingsVM.error ?? "")
            }
        }

        // MARK: - Properties. Private

        @Environment(\.themeManager) private var theme
        @Environment(\.dismiss) private var dismiss
        @Environment(\.openURL) private var openURL
        @State private var purchasingProductID: String?
        @State private var isErrorPresented = false

        private var isDarkAppearance: Bool {
            switch theme.preset {
                case .dark:
                    true

                case .light:
                    false

                case .system:
                    theme.systemColorScheme == .dark
            }
        }

        private var sheetGlassTint: Color {
            isDarkAppearance
                ? Color.white.opacity(0.08)
                : Color.white.opacity(0.35)
        }
        private var lifetimeProduct: Product? {
            settingsVM.products.first { $0.id == ProductID.lifetime }
        }

        private var monthlyProduct: Product? {
            settingsVM.products.first { $0.id == ProductID.monthly }
        }

        private var showsSubscriptionDisclosure: Bool {
            monthlyProduct != nil
                && settingsVM.hasMonthlyPurchase.isFalse
                && settingsVM.hasLifetimePurchase.isFalse
        }

        private var subscriptionDisclosureText: String {
            guard let monthlyProduct else { return "" }

            let price = monthlyProduct.displayPrice
            return L10n.Paywall.disclosureBase(price: price)
                + " "
                + L10n.Paywall.disclosureManage
        }

        // MARK: - Subviews. Private

        private var header: some View {
            VStack(spacing: 10) {
                appIcon

                if settingsVM.hasLifetimePurchase.isFalse {
                    Text(settingsVM.paywallStatusMessage)
                        .font(.satoshi.regular.size(13))
                        .foregroundStyle(theme.tokens.secondaryText)
                        .multilineTextAlignment(.center)
                        .opacity(settingsVM.isLoading ? 0.4 : 1)
                }

                Text(settingsVM.paywallHeaderTitle)
                    .font(.satoshi.bold.size(28))
                    .foregroundStyle(theme.tokens.primaryText)
                    .multilineTextAlignment(.center)

                if settingsVM.hasLifetimePurchase {
                    VStack(spacing: 65) {
                        Text(L10n.Paywall.thanks)
                            .font(.satoshi.medium.size(18))
                            .foregroundStyle(theme.tokens.primaryText)
                            .multilineTextAlignment(.center)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 120, weight: .medium))
                    }
                }
            }
            .padding(.top, 40)
        }

        private var appIcon: some View {
            Image(.paywall)
                .resizable()
                .scaledToFit()
                .cornerRadius(14)
                .frame(size: 50)
        }

        private var purchaseOptions: some View {
            VStack(spacing: 24) {
                if let lifetimeProduct,
                   settingsVM.hasLifetimePurchase.isFalse {
                    purchaseRow(
                        title: L10n.Paywall.productLifetime,
                        subtitle: L10n.Paywall.subtitleUnlock,
                        price: lifetimeProduct.displayPrice,
                        periodLabel: nil,
                        product: lifetimeProduct
                    )
                }

                if let monthlyProduct,
                   settingsVM.hasMonthlyPurchase.isFalse,
                   settingsVM.hasLifetimePurchase.isFalse {
                    purchaseRow(
                        title: L10n.Paywall.productMonthly,
                        subtitle: L10n.Paywall.subtitleUnlock,
                        price: monthlyProduct.displayPrice,
                        periodLabel: L10n.Paywall.everyMonth,
                        product: monthlyProduct
                    )
                }

                if settingsVM.isLoading && settingsVM.products.isEmpty {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
            .padding(.top, 28)
        }

        private var subscriptionDisclosure: some View {
            Text(subscriptionDisclosureText)
                .font(.satoshi.regular.size(11))
                .foregroundStyle(theme.tokens.secondaryText.opacity(0.85))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
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

                    if didPurchase {
                        settingsVM.dismissPaywall()
                        dismiss()
                    } else if settingsVM.error != nil {
                        isErrorPresented = true
                    }
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
            FooterButtonsRow(
                restore: FooterCapsuleButton(
                    title: L10n.Paywall.restore,
                    foreground: theme.tokens.primaryText,
                    action: {
                        Task {
                            await settingsVM.restorePurchases()
                            if settingsVM.error != nil {
                                isErrorPresented = true
                            }
                        }
                    }
                ),
                terms: FooterCapsuleButton(
                    title: L10n.Paywall.terms,
                    foreground: theme.tokens.primaryText,
                    action: {
                        settingsVM.termsOfUseURL.map { openURL($0) }
                    }
                ),
                privacy: FooterCapsuleButton(
                    title: L10n.Paywall.privacy,
                    foreground: theme.tokens.primaryText,
                    action: {
                        settingsVM.privacyPolicyURL.map { openURL($0) }
                    }
                )
            )
            .padding(.bottom, 38)
        }
    }

}

// MARK: - Footer Buttons

private enum FooterButtonsMetrics {
    static let spacing: CGFloat = 8
}

private struct FooterButtonsRow<Restore: View, Terms: View, Privacy: View>: View {
    let restore: Restore
    let terms: Terms
    let privacy: Privacy

    @State private var containerWidth: CGFloat = 0
    @State private var maxNaturalWidth: CGFloat = 0
    @State private var equalHeight: CGFloat = 0

    private var fitsNaturally: Bool {
        guard containerWidth > 0, maxNaturalWidth > 0 else { return true }
        return maxNaturalWidth * 3 + FooterButtonsMetrics.spacing * 2 <= containerWidth
    }

    private var maxButtonWidth: CGFloat {
        guard containerWidth > 0, maxNaturalWidth > 0 else { return 0 }
        if fitsNaturally {
            return maxNaturalWidth
        }
        return max(0, (containerWidth - FooterButtonsMetrics.spacing * 2) / 3)
    }

    var body: some View {
        Group {
            if fitsNaturally {
                HStack(spacing: 0) {
                    restore
                    Spacer(minLength: FooterButtonsMetrics.spacing)
                    terms
                    Spacer(minLength: FooterButtonsMetrics.spacing)
                    privacy
                }
            } else {
                HStack(spacing: FooterButtonsMetrics.spacing) {
                    restore
                    terms
                    privacy
                }
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FooterContainerWidthKey.self,
                    value: proxy.size.width
                )
            }
        }
        .onPreferenceChange(FooterContainerWidthKey.self) { containerWidth = $0 }
        .onPreferenceChange(FooterNaturalWidthKey.self) { maxNaturalWidth = $0 }
        .onPreferenceChange(FooterEqualHeightKey.self) { equalHeight = $0 }
        .environment(\.footerMaxButtonWidth, maxButtonWidth)
        .environment(\.footerEqualButtonHeight, equalHeight)
    }
}

private struct FooterCapsuleButton: View {
    let title: String
    let foreground: Color
    let action: () -> Void

    @Environment(\.footerMaxButtonWidth) private var maxButtonWidth
    @Environment(\.footerEqualButtonHeight) private var equalHeight

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.satoshi.medium.size(14))
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(width: maxButtonWidth > 0 ? maxButtonWidth : nil)
                .frame(height: equalHeight > 0 ? equalHeight : nil)
                .background {
                    Color.clear.footerEqualHeightReader()
                }
                .background(alignment: .leading) {
                    Text(title)
                        .font(.satoshi.medium.size(14))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .fixedSize(horizontal: true, vertical: false)
                        .hidden()
                        .overlay {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: FooterNaturalWidthKey.self,
                                    value: proxy.size.width
                                )
                            }
                        }
                }
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

private struct FooterEqualHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FooterNaturalWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FooterContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func footerEqualHeightReader() -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: FooterEqualHeightKey.self,
                value: proxy.size.height
            )
        }
    }
}

private struct FooterMaxButtonWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct FooterEqualButtonHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private extension EnvironmentValues {
    var footerMaxButtonWidth: CGFloat {
        get { self[FooterMaxButtonWidthKey.self] }
        set { self[FooterMaxButtonWidthKey.self] = newValue }
    }

    var footerEqualButtonHeight: CGFloat {
        get { self[FooterEqualButtonHeightKey.self] }
        set { self[FooterEqualButtonHeightKey.self] = newValue }
    }
}

#Preview {
    PaywallView()
        .frame(maxWidth: .infinity)
        .frame(height: 400)
        .environment(\.themeManager, ThemeManager())
}
