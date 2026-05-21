//
//  TransferQueueStorage.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 21.05.2026.
//

import Foundation

struct TransferDownloadSession: Equatable {
    var activeTrackIDs: [String]
    var queuedTrackIDs: [String]
}

enum TransferQueueStorage {
    private static let activeKey = "transfer.downloadSession.active"
    private static let queueKey = "transfer.downloadSession.queue"

    static func load() -> TransferDownloadSession {
        TransferDownloadSession(
            activeTrackIDs: UserDefaults.standard.stringArray(forKey: self.activeKey) ?? [],
            queuedTrackIDs: UserDefaults.standard.stringArray(forKey: self.queueKey) ?? []
        )
    }

    static func save(session: TransferDownloadSession) {
        UserDefaults.standard.set(session.activeTrackIDs, forKey: self.activeKey)
        UserDefaults.standard.set(session.queuedTrackIDs, forKey: self.queueKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: self.activeKey)
        UserDefaults.standard.removeObject(forKey: self.queueKey)
    }
}
