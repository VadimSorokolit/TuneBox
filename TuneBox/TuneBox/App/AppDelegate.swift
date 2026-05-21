//
//  AppDelegate.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 12.05.2026.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Initializer

    func configure(networkService: NetworkServicing) {
        self.networkService = networkService

    }

    // MARK: - Methods. Public

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        self.networkService?.handleBackgroundCompletion(completionHandler)
    }

    // MARK: - Properties. Private

    private weak var networkService: NetworkServicing?
}
