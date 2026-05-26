//
//  TransferDownloadObserverTokens.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 19.05.2026.
//

import Foundation

final class TransferDownloadObserverTokens: @unchecked Sendable {
    var progressToken: NSObjectProtocol?
    var finishedToken: NSObjectProtocol?

    deinit {
        if let progressToken {
            NotificationCenter.default.removeObserver(progressToken)
        }
        if let finishedToken {
            NotificationCenter.default.removeObserver(finishedToken)
        }
    }
}
