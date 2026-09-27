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
import UIKit
import LinkPresentation

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
    private(set) var isSleepTimerActive = false
    private(set) var sleepTimerTrailingText = "Off"

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

    var marketingVersion: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String

        guard let version, version.isNotEmpty else {
            return Constants.fallbackVersion
        }

        return version
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
        self.analytics.log(
            .purchase(
                product: Self.analyticsProductName(for: product),
                success: didPurchase
            )
        )

        if didPurchase.isFalse, let message = self.purchaseService.error {
            self.crashlytics.record(
                NSError(
                    domain: "com.TuneBox.purchase",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: message]
                ),
                area: .purchase
            )
        }

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
        let wasPresented = self.isPaywallPresented
        self.isPaywallPresented = true

        guard wasPresented.isFalse else { return }

        self.analytics.log(.paywallView)
    }

    func dismissPaywall() {
        self.isPaywallPresented = false
    }

    var termsOfUseURL: URL {
        URL(string: Constants.termsOfUseURL)!
    }

    var privacyPolicyURL: URL? {
        URL(string: Constants.privacyPolicyURL)
    }

    var shareActivityItems: [Any] {
        [AppShareItem(
            title: Constants.shareAppTitle,
            message: Constants.shareAppMessage,
            image: UIImage(named: Constants.shareAppImageName)
        )]
    }

    func startSleepTimer(hours: Int, minutes: Int) {
        let duration = TimeInterval((hours * 60) + minutes) * 60
        guard duration > 0 else { return }

        self.cancelSleepTimer()

        let endDate = Date().addingTimeInterval(duration)
        self.sleepTimerEndDate = endDate
        self.isSleepTimerActive = true
        self.sleepTimerTrailingText = Self.formattedRemaining(
            endDate.timeIntervalSinceNow
        )

        let fireTimer = Timer(
            timeInterval: duration,
            repeats: false
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.fireSleepTimer()
            }
        }
        RunLoop.main.add(fireTimer, forMode: .common)
        self.sleepTimer = fireTimer

        let tickTimer = Timer(
            timeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshSleepTimerDisplay()
            }
        }
        RunLoop.main.add(tickTimer, forMode: .common)
        self.sleepTimerDisplayTimer = tickTimer
    }

    func cancelSleepTimer() {
        self.sleepTimer?.invalidate()
        self.sleepTimer = nil
        self.sleepTimerDisplayTimer?.invalidate()
        self.sleepTimerDisplayTimer = nil
        self.sleepTimerEndDate = nil
        self.isSleepTimerActive = false
        self.sleepTimerTrailingText = "Off"
    }

    func submitFeedback(
        rating: Int,
        ratingLabel: String,
        emoji: String,
        comment: String
    ) async throws {
        try await self.feedbackService.submit(
            rating: rating,
            ratingLabel: ratingLabel,
            emoji: emoji,
            comment: comment
        )
    }

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

    private enum Constants {
        static let fallbackVersion = "1.0"
        static let termsOfUseURL =
            "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        static let privacyPolicyURL =
            "https://sites.google.com/view/tunebox-privacy-policy/privacy"
        static let shareAppTitle = "TuneBox"
        static let shareAppMessage =
            "Check out TuneBox — an offline music player for iPhone."
        static let shareAppImageName = "Paywall"
    }

    @ObservationIgnored
    @Injected private var purchaseService: PurchaseServicing

    @ObservationIgnored
    @Injected private var entitlementService: EntitlementServicing

    @ObservationIgnored
    @Injected private var analytics: AnalyticsServicing

    @ObservationIgnored
    @Injected private var crashlytics: CrashlyticsServicing

    @ObservationIgnored
    @Injected private var feedbackService: FeedbackServicing

    @ObservationIgnored
    @Injected private var audioService: AudioServicing

    @ObservationIgnored
    private var sleepTimer: Timer?

    @ObservationIgnored
    private var sleepTimerDisplayTimer: Timer?

    @ObservationIgnored
    private var sleepTimerEndDate: Date?

    // MARK: - Methods. Private

    private static func analyticsProductName(for product: Product) -> String {
        switch product.id {
            case ProductID.monthly:
                "monthly"

            case ProductID.lifetime:
                "lifetime"

            default:
                "unknown"
        }
    }

    private func syncFromServices() {
        self.products = self.purchaseService.products
        self.purchasedProductIDs = self.purchaseService.purchasedProductIDs
        self.isLoading = self.purchaseService.isLoading
        self.error = self.purchaseService.error
        self.hasPremium = self.entitlementService.hasPremium
        self.paywallStatusMessage = self.entitlementService.paywallStatusMessage
    }

    private func refreshSleepTimerDisplay() {
        guard let endDate = self.sleepTimerEndDate else {
            self.sleepTimerTrailingText = "Off"
            self.isSleepTimerActive = false
            return
        }

        let remaining = endDate.timeIntervalSinceNow
        guard remaining > 0 else {
            self.fireSleepTimer()
            return
        }

        self.sleepTimerTrailingText = Self.formattedRemaining(remaining)
    }

    private func fireSleepTimer() {
        self.cancelSleepTimer()
        self.audioService.stop()
        exit(0)
    }

    private static func formattedRemaining(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded(.up)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AppShareItem

private final class AppShareItem: NSObject, UIActivityItemSource {

    // MARK: - Properties. Private

    private let title: String
    private let message: String
    private let image: UIImage?

    // MARK: - Initializer

    init(title: String, message: String, image: UIImage?) {
        self.title = title
        self.message = message
        self.image = image
    }

    // MARK: - Methods. Public

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        message
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        message
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = URL(fileURLWithPath: title)

        if let image {
            metadata.iconProvider = NSItemProvider(object: image)
            metadata.imageProvider = NSItemProvider(object: image)
        }

        return metadata
    }
}
