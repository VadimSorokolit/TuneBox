//
//  AppDelegate.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 12.05.2026.
//

import UIKit
import Resolver
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Methods. Public
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        let semaphore = DispatchSemaphore(value: 0)

        self.playerViewModel.stopAudioPreservingSession()

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
