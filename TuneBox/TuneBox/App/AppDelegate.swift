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
        self.viewModel = viewModel
    }

    // MARK: - Methods. Public

    func applicationDidEnterBackground(_ application: UIApplication) {
        self.viewModel?.saveTransferState()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        guard let viewModel = self.viewModel else {
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        Task { @MainActor in
            await viewModel.snapshotForTerminate()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 4.0)
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
    private weak var viewModel: TransferManaging?
}
