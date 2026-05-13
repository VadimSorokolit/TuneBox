//
//  DownloadCoordinator.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Foundation

actor DownloadCoordinator {
    private var maxConcurrent: Int
    private var activeIDs: Set<String> = []
    private var pending: [Track] = []
    private var pendingIDs: Set<String> = []

    init(maxConcurrent: Int) {
        self.maxConcurrent = maxConcurrent
    }

    func setMaxConcurrent(
        _ value: Int,
        start: @Sendable @escaping (Track) async throws -> Void
    ) async {
        maxConcurrent = max(1, value)

        while activeIDs.count < maxConcurrent,
              let next = pending.first {

            pending.removeFirst()
            pendingIDs.remove(next.id)

            await run(next, start: start)
        }
    }

    func userRequestedDownload(
        _ track: Track,
        start: @Sendable @escaping (Track) async throws -> Void
    ) async {
        guard !activeIDs.contains(track.id) else { return }
        guard !pendingIDs.contains(track.id) else { return }

        if activeIDs.count < maxConcurrent {
            await run(track, start: start)
        } else {
            pending.append(track)
            pendingIDs.insert(track.id)
        }
    }

    private func run(
        _ track: Track,
        start: @Sendable @escaping (Track) async throws -> Void
    ) async {
        activeIDs.insert(track.id)

        Task {
            defer {
                Task {
                    await self.finished(
                        trackID: track.id,
                        start: start
                    )
                }
            }

            try? await start(track)
        }
    }

    private func finished(
        trackID: String,
        start: @Sendable @escaping (Track) async throws -> Void
    ) async {
        activeIDs.remove(trackID)

        while activeIDs.count < maxConcurrent,
              let next = pending.first {

            pending.removeFirst()
            pendingIDs.remove(next.id)

            await run(next, start: start)
        }
    }
}
