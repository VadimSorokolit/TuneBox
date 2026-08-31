//
//  TransferDownloadObserverTokens.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 19.05.2026.
//

import Foundation

final class TransferDownloadObserverTokens: @unchecked Sendable {

    // MARK: - Properties. Public

    var progressToken: NSObjectProtocol?
    var finishedToken: NSObjectProtocol?
    var failedToken: NSObjectProtocol?
    var interruptedToken: NSObjectProtocol?

    // MARK: - Deinitializer

    deinit {
        if let progressToken {
            NotificationCenter.default.removeObserver(progressToken)
        }
        if let finishedToken {
            NotificationCenter.default.removeObserver(finishedToken)
        }
        if let failedToken {
            NotificationCenter.default.removeObserver(failedToken)
        }
        if let interruptedToken {
            NotificationCenter.default.removeObserver(interruptedToken)
        }
    }
}
