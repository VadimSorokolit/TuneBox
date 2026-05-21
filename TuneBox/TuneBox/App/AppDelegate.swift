//
//  AppDelegate.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 12.05.2026.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Initializer

    func configure(
        networkService: NetworkServicing,
        viewModel: TransferManaging
    ) {
        self.networkService = networkService
        self.onSaveStateBeforeClose = { viewModel.saveStateBeforeClose() }
    }

    // MARK: - Methods. Public

    func applicationDidEnterBackground(_ application: UIApplication) {
        self.onSaveStateBeforeClose?()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        self.onSaveStateBeforeClose?()
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        self.networkService?.handleBackgroundCompletion(completionHandler)
    }

    // MARK: - Properties. Private

    private weak var networkService: NetworkServicing?
    private var onSaveStateBeforeClose: (() -> Void)?
}
