//
//  AppDelegate.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 12.05.2026.
//

import UIKit
import Resolver

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Methods. Public

    func applicationWillTerminate(_ application: UIApplication) {
        let semaphore = DispatchSemaphore(value: 0)

        self.playerViewModel.resetPlayback()

        Task { @MainActor in
            await self.viewModel.snapshotForTerminate()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 4.0)
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        self.viewModel.handleBackgroundCompletion(completionHandler)
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: TransferManaging
    @Injected private var playerViewModel: PlayerManaging
}
