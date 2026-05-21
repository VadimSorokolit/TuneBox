//
//  NotificationNames+Extension.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 11.05.2026.
//

import Foundation

extension Notification.Name {

    static let trackDownloadDidFinish = Notification.Name("trackDownloadDidFinish")
    static let trackDownloadDidFail = Notification.Name("trackDownloadDidFail")
    static let trackDownloadDidInterrupt = Notification.Name("trackDownloadDidInterrupt")
    static let trackDownloadProgress = Notification.Name("trackDownloadProgress")

}
