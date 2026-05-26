//
//  TransferViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Foundation
import Observation

enum ReservedSpace: Int {
    case oneGB = 1
    case twoGB = 2
    case fiveGB = 5
}

enum SimultaneouslyLoadingCount: Int {
    case two = 2
    case three = 3
    case four = 4
    case five = 5
}

protocol TransferManaging:
    DownloadManaging,
    DownloadStateProviding,
    StorageManaging,
    PersistenceManaging {
    func loadFirst() async
    func loadNext() async
    func startDownload(_ track: TrackEntity) async
    func resetTransferState()
    func saveTransferState()
    func snapshotForTerminate() async
    func handleBackgroundCompletion(_ handler: @escaping () -> Void)
    func restoreDownloadsOnForeground() async
    func handleDownloadAction(for track: TrackEntity) async
}

@MainActor
@Observable
final class TransferViewModel: TransferManaging {

    // MARK: Properties. Public

    private(set) var offset: Int = .zero
    private(set) var tracks: [TrackEntity] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?
    private(set) var inProgressTrackIDs: Set<String> = []
    private(set) var simultaneouslyLoadingCount: Int = SimultaneouslyLoadingCount.two.rawValue
    private(set) var reservedSpace: ReservedSpace = ReservedSpace.oneGB

    var availableSpace: Double? {
        self.storageService.getFreeStorage()
    }

    // MARK: - Methods. Public

    func loadFirst() async {
        guard self.isLoading == false else {
            return
        }

        self.isLoading = true
        defer {
            self.isLoading = false
        }

        do {
            let entities = try self.persistenceService.getTracks()

            if entities.isEmpty {
                self.offset = .zero
                self.tracks = await self.loadTracks(offset: self.offset)
                self.offset += self.tracks.count
            } else {
                self.tracks = entities

                self.seedPersistedProgressBaseline()
                await self.networkService.restoreDownloadSession()
                await self.networkService.waitForPendingCancellations(timeout: 2.5)
                await self.restoreInterruptedDownloads()
                await self.processDownloadQueue()
            }
        } catch {
            self.handleError(error)
        }
    }

    func loadNext() async {
        guard self.isLoading == false else {
            return
        }

        self.isLoading = true
        defer {
            self.isLoading = false
        }
        let newEntityTracks = await self.loadTracks(offset: self.offset)
        self.tracks.append(contentsOf: newEntityTracks)
    }

    func startDownload(_ track: TrackEntity) async {
        guard self.hasEnoughFreeSpace(for: track) else {
            return
        }

        if track.downloadingSize != .zero {
            await self.resumeDownload(track: track)
            return
        }

        if self.hasFreeDownloadSlot == false {
            self.enqueueDownload(track: track)
            return
        }

        await self.activateDownload(track: track)
    }

    func stopDownload(track: TrackEntity) async {
        await self.networkService.stopDownload(trackId: track.id)
        await self.finishActiveDownload(trackId: track.id)

        track.downloadState = .paused
        track.fileState = .exists

        let bytes = track.downloadingSize
        let readable = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        self.logTransferWarning("Paused track \(track.id): \(readable) (\(bytes) B)")
    }

    func resumeDownload(track: TrackEntity) async {
        guard self.hasEnoughFreeSpace(for: track) else {
            return
        }

        if self.hasFreeDownloadSlot == false {
            self.enqueueDownload(track: track)
            return
        }

        await self.activateResumeDownload(track: track)
    }

    func cancelQueuedDownload(track: TrackEntity) {
        guard track.downloadState == .queued else {
            return
        }

        self.downloadQueue.removeAll { $0 == track.id }
        track.downloadState = .idle
        track.fileState = .none
        track.downloadingSize = .zero

        self.persistDownloadSession()
    }

    func saveTransferState() {
        self.persistDownloadSession()
    }

    func snapshotForTerminate() async {
        self.saveTransferState()
        await self.networkService.snapshotResumeDataForRelaunch()
    }

    func restoreDownloadsOnForeground() async {
        await self.networkService.restoreDownloadSession()
        let running = await self.networkService.runningDownloadTrackIDs()

        for trackID in running {
            self.inProgressTrackIDs.insert(trackID)
            self.registerActiveDownload(trackID)

            if let track = self.tracks.first(where: { $0.id == trackID }) {
                if track.downloadState != .downloading {
                    track.downloadState = .downloading
                }
            } else {
                continue
            }
        }

        await self.processDownloadQueue()
    }

    func deleteDownloadedTrack(track: TrackEntity) {
        self.networkService.clearPersistedResumeData(trackId: track.id)

        do {
            try self.storageService.deleteDownloadedTrack(id: track.id)
            track.downloadState = .idle
            track.fileState = .removed
            track.downloadingSize = .zero
        } catch {
            self.handleError(error)
        }
    }

    func setSimultaneouslyLoadingLimit(_ limit: Int) {
        self.simultaneouslyLoadingCount = limit
    }

    func applyReservedSpace(_ plan: ReservedSpace) {
        do {
            try self.storageService.checkEnoughFreeStorage(requiredGB: Double(plan.rawValue))
            self.reservedSpace = plan
        } catch {
            self.handleError(error)
        }
    }

    func handleBackgroundCompletion(_ handler: @escaping () -> Void) {
        self.networkService.setBackgroundCompletionHandler(handler)
    }

    func handleDownloadAction(for track: TrackEntity) async {
        switch track.downloadState {
            case .idle:
                await startDownload(track)

            case .paused:
                await resumeDownload(track: track)

            case .downloading:
                await stopDownload(track: track)

            case .completed:
                deleteDownloadedTrack(track: track)

            case .queued:
                cancelQueuedDownload(track: track)

            case .failed:
                self.error = nil
                await self.startDownload(track)
        }
    }

    // MARK: - Only for testing!!!

    func resetTransferState() {
        Task {
            await self.networkService.cancelAllDownloads()
        }

        self.downloadQueue.removeAll()
        self.activeDownloadOrder.removeAll()
        self.inProgressTrackIDs.removeAll()
        self.tracks.removeAll()

        TransferQueueStorage.clear()

        do {
            try self.persistenceService.clearStorage()

            do {
                try self.storageService.clearStorage()
                self.clearDownloadState()
                self.offset = .zero
            } catch {
                self.handleError(error)
            }
        } catch {
            self.handleError(error)
        }
    }

    // MARK: - Initializer

    init(
        networkService: NetworkServicing,
        persistenceService: PersistenceServicing,
        storageService: FileManagerServicing
    ) {
        self.networkService = networkService
        self.persistenceService = persistenceService
        self.storageService = storageService

        let mainQueue = OperationQueue.main
        self.downloadObserverTokens.progressToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadProgress,
            object: nil,
            queue: mainQueue
        ) { notification in
            guard
                let trackID: String = self.getValue(
                    for: TrackDownloadNotificationUserInfoKey.trackID,
                    from: notification
                ),
                let trackDownloadedBytes: Int64 = self.getValue(
                    for: TrackDownloadNotificationUserInfoKey.totalBytesWritten,
                    from: notification
                )
            else {
                return
            }

            Task { @MainActor [weak self, trackID, trackDownloadedBytes] in
                guard let self else { return }
                self.applyDownloadProgress(trackID: trackID, totalBytesWritten: trackDownloadedBytes)
            }
        }

        self.downloadObserverTokens.finishedToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadDidFinish,
            object: nil,
            queue: mainQueue
        ) { notification in
            guard
                let trackID: String = self.getValue(
                    for: TrackDownloadNotificationUserInfoKey.trackID,
                    from: notification
                ) else {
                return
            }

            Task { @MainActor [weak self, trackID] in
                guard let self else { return }
                self.applyDownloadFinished(trackID: trackID)
            }
        }

        self.downloadObserverTokens.failedToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadDidFail,
            object: nil,
            queue: mainQueue
        ) { notification in
            guard
                let trackID: String = self.getValue(
                    for: TrackDownloadNotificationUserInfoKey.trackID,
                    from: notification
                ),
                let error: Error = self.getValue(
                    for: TrackDownloadNotificationUserInfoKey.error,
                    from: notification
                )
            else {
                return
            }

            Task { @MainActor [weak self, trackID, error] in
                guard let self else { return }
                self.applyDownloadFailed(trackID: trackID, error: error)
            }
        }

        self.downloadObserverTokens.interruptedToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadDidInterrupt,
            object: nil,
            queue: mainQueue
        ) { notification in
            guard
                let trackID: String = self.getValue(
                    for: TrackDownloadNotificationUserInfoKey.trackID,
                    from: notification
                )
            else {
                return
            }

            Task { @MainActor [weak self, trackID] in
                guard let self else { return }
                await self.applyDownloadInterrupted(trackID: trackID)
            }
        }
    }

    // MARK: - Properties. Private

    private let limit: Int = 8
    private let networkService: NetworkServicing
    private let persistenceService: PersistenceServicing
    private let storageService: FileManagerServicing
    private let downloadObserverTokens = TransferDownloadObserverTokens()
    private var downloadQueue: [String] = []
    private var activeDownloadOrder: [String] = []
    private var lastPersistedProgressBytesByTrackID: [String: Int] = [:]
    private let progressPersistStepBytes = 65_536

    // MARK: - Methods. Private

    private func loadTracks(offset: Int) async -> [TrackEntity] {
        do {
            let dtos = try await self.networkService.getPopularTracks(
                limit: self.limit,
                offset: offset
            )
            self.offset = offset

            let entities = dtos.map(TrackEntity.init)

            do {
                try self.persistenceService.insert(tracks: entities)
            } catch {
                self.handleError(error)
            }

            return entities
        } catch {
            self.handleError(error)
        }

        return []
    }

    private func getTrack(id: String) -> TrackEntity? {
        do {
            return try self.persistenceService.getTrack(id: id)
        } catch {
            self.handleError(error)
            return nil
        }
    }

    private var hasFreeDownloadSlot: Bool {
        self.inProgressTrackIDs.count < self.simultaneouslyLoadingCount
    }

    private func restoreInterruptedDownloads() async {
        let liveActive = await self.networkService.runningDownloadTrackIDs()
        let savedSession = TransferQueueStorage.load()

        for track in self.tracks
        where self.storageService.downloadedTrackExists(id: track.id) {
            track.downloadingSize = track.size ?? track.downloadingSize
            track.downloadState = .completed
            track.fileState = .exists
        }

        var queuedInOrder: [String] = []

        for trackID in savedSession.activeTrackIDs {
            if let track = self.tracks.first(where: { $0.id == trackID }) {
                if track.downloadState == .completed {
                    continue
                }

                if liveActive.contains(trackID) {
                    self.inProgressTrackIDs.insert(trackID)
                    self.registerActiveDownload(trackID)
                    track.downloadState = .downloading

                    continue
                }

                track.downloadState = .queued
                queuedInOrder.append(trackID)
            } else {
                continue
            }
        }

        for trackID in savedSession.queuedTrackIDs where queuedInOrder.contains(trackID) == false {
            if let track = self.tracks.first(where: { $0.id == trackID }) {
                if track.downloadState == .completed {
                    continue
                }

                track.downloadState = .queued

                queuedInOrder.append(trackID)
            } else {
                continue
            }
        }

        for track in self.tracks
        where track.downloadState == .queued {

            if queuedInOrder.contains(track.id) == false {
                queuedInOrder.append(track.id)
            }
        }

        for track in self.tracks
        where track.downloadState == .downloading {
            if liveActive.contains(track.id) {
                continue
            }

            track.downloadState = .queued

            if queuedInOrder.contains(track.id) == false {
                queuedInOrder.insert(track.id, at: .zero)
            }
        }

        self.downloadQueue = queuedInOrder
        self.persistDownloadSession()
    }

    private func clearDownloadState() {
        for track in self.tracks {
            track.downloadingSize = .zero
            track.downloadState = .idle
        }
    }

    private func seedPersistedProgressBaseline() {
        for track in self.tracks where track.downloadState == .downloading {
            self.lastPersistedProgressBytesByTrackID[track.id] = track.downloadingSize
        }
    }

    private func enqueueDownload(track: TrackEntity) {
        guard self.downloadQueue.contains(track.id) == false else {
            return
        }

        self.downloadQueue.append(track.id)
        track.downloadState = .queued
        self.persistDownloadSession()
    }

    private func activateDownload(track: TrackEntity) async {
        self.inProgressTrackIDs.insert(track.id)
        self.registerActiveDownload(track.id)
        track.downloadState = .downloading
        self.lastPersistedProgressBytesByTrackID[track.id] = track.downloadingSize
        self.persistDownloadSession()

        do {
            try await self.networkService.startDownload(track)
        } catch {
            self.markDownloadFailed(track: track)
            self.handleError(error)
            await self.finishActiveDownload(trackId: track.id)
        }
    }

    private func activateResumeDownload(track: TrackEntity) async {
        self.inProgressTrackIDs.insert(track.id)
        self.registerActiveDownload(track.id)
        track.downloadState = .downloading
        self.lastPersistedProgressBytesByTrackID[track.id] = track.downloadingSize
        self.persistDownloadSession()

        do {
            try await self.networkService.resumeDownload(trackId: track.id)
        } catch {
            self.logTransferWarning("Resume failed for \(track.id), restarting from scratch: \(error.localizedDescription)")
            self.networkService.clearPersistedResumeData(trackId: track.id)

            do {
                try await self.networkService.startDownload(track)
            } catch {
                self.markDownloadFailed(track: track)
                self.handleError(error)

                await self.finishActiveDownload(trackId: track.id)
            }
        }
    }

    private func finishActiveDownload(trackId: String) async {
        self.inProgressTrackIDs.remove(trackId)
        self.unregisterActiveDownload(trackId)
        self.persistDownloadSession()
        await self.processDownloadQueue()
    }

    private func processDownloadQueue() async {
        while self.hasFreeDownloadSlot, self.downloadQueue.isEmpty == false {
            let trackID = self.downloadQueue.removeFirst()

            if let track = self.tracks.first(where: { $0.id == trackID }) {
                guard track.downloadState == .queued else {
                    continue
                }

                guard self.hasEnoughFreeSpace(for: track) else {
                    track.downloadState = .idle

                    continue
                }

                let hasResumeData = await self.networkService.hasPersistedResumeData(trackId: trackID)

                if hasResumeData {
                    await self.activateResumeDownload(track: track)
                } else {
                    await self.activateDownload(track: track)
                }
            }

            self.persistDownloadSession()
        }
    }

    private func persistDownloadSession() {
        TransferQueueStorage.save(
            session: TransferDownloadSession(
                activeTrackIDs: self.activeDownloadOrder,
                queuedTrackIDs: self.downloadQueue
            )
        )
    }

    private func registerActiveDownload(_ trackID: String) {
        guard self.activeDownloadOrder.contains(trackID) == false else {
            return
        }

        self.activeDownloadOrder.append(trackID)
    }

    private func unregisterActiveDownload(_ trackID: String) {
        self.activeDownloadOrder.removeAll { $0 == trackID }
    }

    private func hasEnoughFreeSpace(for track: TrackEntity) -> Bool {
        guard let size = track.size else {
            return true
        }

        let requiredGB = Double(size) / GlobalConstants.bytesInGigabyte
        let available = self.storageService.getFreeStorage() ?? .zero

        guard available >= requiredGB else {
            let error = "Not enough free space on device"
            self.error = error
            self.logTransferWarning(error)
            return false
        }

        return true
    }

    private func applyDownloadProgress(trackID: String, totalBytesWritten: Int64) {
        if let track = self.tracks.first(where: { $0.id == trackID }) {
            let reportedBytes = Int(min(totalBytesWritten, Int64(Int.max)))
            let previousBytes = track.downloadingSize
            let displayedBytes = max(previousBytes, reportedBytes)

            track.downloadingSize = displayedBytes

            guard track.downloadState == .downloading else {
                return
            }

            let lastPersisted = self.lastPersistedProgressBytesByTrackID[trackID] ?? .zero
            let shouldPersist = (displayedBytes - lastPersisted) >= self.progressPersistStepBytes
            || displayedBytes == track.size

            guard shouldPersist else {
                return
            }

            self.lastPersistedProgressBytesByTrackID[trackID] = displayedBytes
        }
    }

    private func applyDownloadFinished(trackID: String) {
        if let track = self.tracks.first(where: { $0.id == trackID }) {
            track.downloadingSize = track.size ?? .zero
            track.downloadState = .completed
            track.fileState = .exists

            Task {
                await self.finishActiveDownload(trackId: trackID)
            }
        } else {
            return
        }
    }

    private func applyDownloadFailed(trackID: String, error: Any) {
        if let track = self.tracks.first(where: { $0.id == trackID }) {
            self.markDownloadFailed(track: track)

            if let apiError = error as? APIError {
                self.handleError(apiError)
            } else if let localizedError = error as? Error {
                self.handleError(localizedError)
            } else {
                self.handleError(APIError.unknown)
            }

            Task {
                await self.finishActiveDownload(trackId: trackID)
            }
        }
    }

    private func applyDownloadInterrupted(trackID: String) async {
        self.inProgressTrackIDs.remove(trackID)
        self.unregisterActiveDownload(trackID)

        if let track = self.tracks.first(where: { $0.id == trackID }) {
            if track.downloadState == .paused {
                self.persistDownloadSession()
                await self.processDownloadQueue()
                return
            }

            if self.downloadQueue.contains(trackID) == false {
                self.downloadQueue.insert(trackID, at: .zero)
            }

            track.downloadState = .queued

            self.persistDownloadSession()

            await self.processDownloadQueue()
        } else {
            self.persistDownloadSession()
            await self.processDownloadQueue()

            return
        }
    }

    nonisolated
    private func getValue<T>(for key: String, from notification: Notification) -> T? {
        notification.userInfo?[key] as? T
    }

    private func logTransferWarning(_ message: String) {
        AppLogger.transfer.warning("\(message)")
    }

    private func markDownloadFailed(track: TrackEntity) {
        track.downloadState = .failed
        track.fileState = .none
        track.downloadingSize = .zero
    }

    private func handleError(_ error: Error) {
        let error = error.localizedDescription
        self.error = error
        self.logTransferWarning(error)
    }
}
