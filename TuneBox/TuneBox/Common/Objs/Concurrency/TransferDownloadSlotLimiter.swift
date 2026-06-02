//
//  TransferDownloadSlotLimiter.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 19.05.2026.
//

import Foundation
import Synchronization

final class TransferDownloadSlotLimiter: Sendable {

    // MARK: - Methods. Private

    func acquire(limit: Int) async {
        await withCheckedContinuation { continuation in
            self.mutex.withLock { state in
                if state.activeDownloadCount < limit {
                    state.activeDownloadCount += 1
                    continuation.resume()
                } else {
                    state.waiters.append(continuation)
                }
            }
        }
    }

    func release() {
        self.mutex.withLock { state in
            if let waiter = state.waiters.first {
                state.waiters.removeFirst()
                waiter.resume()
            } else if state.activeDownloadCount > 0 {
                state.activeDownloadCount -= 1
            }
        }
    }

    // MARK: - Properties. Private

    private struct State {
        var activeDownloadCount = 0
        var waiters: [CheckedContinuation<Void, Never>] = []
    }

    private let mutex = Mutex(State())
}
