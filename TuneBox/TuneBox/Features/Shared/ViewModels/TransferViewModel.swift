//
//  TransferViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Foundation
import Observation

enum ReservedSpace: Int, CaseIterable {
    case oneGB = 1
    case twoGB = 2
    case fiveGB = 5

    var gigabytes: Double {
        Double(self.rawValue)
    }
}

enum SimultaneouslyLoadingCount: Int, CaseIterable {
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
    func cancelAllDownloads() async
    func resetTransferState() async
    func saveTransferState()
    func snapshotForTerminate() async
    func handleBackgroundCompletion(_ handler: @escaping () -> Void)
    func restoreDownloadsOnForeground() async
    func handleDownloadAction(for track: TrackEntity) async
}

@MainActor
@Observable
final class TransferViewModel: TransferManaging {

    // MARK: - Properties. Public

    private(set) var offset: Int = .zero
    private(set) var tracks: [TrackEntity] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?
    private(set) var inProgressTrackIDs: Set<String> = []
    private(set) var simultaneouslyLoadingCount: Int = SimultaneouslyLoadingCount.two.rawValue
    private(set) var reservedSpace: ReservedSpace = .oneGB

    var availableSpace: Double? {
        self.storageService.getFreeStorage()
    }

    // MARK: - Methods. Public

    func loadFirst() {
        self.cancelLoadTask()

        self.loadTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.isLoading = true

            defer {
                self.isLoading = false
                self.loadTask = nil
            }

            do {
                let persistedEntities = try self.persistenceService.getTracks()
                try Task.checkCancellation()

                if persistedEntities.isEmpty {
                    try await self.loadInitialTracks()
                } else {
                    await self.restoreFromPersistedState(persistedEntities)
                }
            } catch is CancellationError {
                AppLogger.network.debug("Load cancelled")
            } catch {
                self.handleError(error)
            }
        }
    }

    func loadNext() {
        guard self.isLoading == false else {
            return
        }

        self.cancelLoadTask()

        self.loadTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.isLoading = true

            defer {
                self.isLoading = false
                self.loadTask = nil
            }

            do {
                let newTracks = await self.loadTracks(offset: self.offset)
                try Task.checkCancellation()

                self.tracks.append(contentsOf: newTracks)
                self.offset += newTracks.count
            } catch is CancellationError {
                AppLogger.network.debug("Load cancelled")
            } catch {
                self.handleError(error)
            }
        }
    }

    func startDownload(_ track: TrackEntity) async {
        guard self.hasEnoughFreeSpace(for: track) else {
            return
        }

        if track.downloadingSize != .zero {
            await self.resumeDownload(track: track)
            return
        }

        guard self.hasFreeDownloadSlot else {
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

        self.logTransferWarning("Paused track \(track.id): \(self.formatBytes(track.downloadingSize))")
    }

    func resumeDownload(track: TrackEntity) async {
        guard self.hasEnoughFreeSpace(for: track) else {
            return
        }

        guard self.hasFreeDownloadSlot else {
            self.enqueueDownload(track: track)
            return
        }

        await self.activateResumeDownload(track: track)
    }

    func cancelQueuedDownload(track: TrackEntity) {
        guard track.downloadState == .queued else {
            return
        }

        self.queuedDownloadTrackIDs.removeAll { $0 == track.id }
        self.resetTrackState(track, to: .idle, fileState: FileStorageState.none)
        self.persistDownloadSession()
    }

    func saveTransferState() {
        self.persistDownloadSession(force: true)
    }

    func snapshotForTerminate() async {
        self.saveTransferState()
        await self.networkService.snapshotResumeDataForRelaunch()
    }

    func cancelAllDownloads() async {
        await self.networkService.cancelAllDownloads()
        self.inProgressTrackIDs.removeAll()
        self.queuedDownloadTrackIDs.removeAll()

        for track in self.tracks {
            switch track.downloadState {
                case .downloading,
                        .queued,
                        .paused,
                        .failed:

                    self.resetTrackState(track, to: .idle, fileState: FileStorageState.none)

                case .completed,
                        .idle:

                    break
            }
        }

        self.persistDownloadSession(force: true)
    }

    func restoreDownloadsOnForeground() async {
        await self.networkService.restoreDownloadSession()
        let runningTrackIDs = await self.networkService.runningDownloadTrackIDs()

        for trackID in runningTrackIDs {
            self.inProgressTrackIDs.insert(trackID)

            if let track = self.track(byID: trackID), track.downloadState != .downloading {
                track.downloadState = .downloading
            }
        }

        await self.processDownloadQueue()
    }

    func deleteDownloadedTrack(track: TrackEntity) {
        self.networkService.clearPersistedResumeData(trackId: track.id)

        if AudioService.shared.currentTrackId == track.id {
            AudioService.shared.stop()
        }

        do {
            try self.storageService.deleteDownloadedTrack(id: track.id)
            self.resetTrackState(track, to: .idle, fileState: .removed)
        } catch {
            self.handleError(error)
        }
    }

    func setSimultaneouslyLoadingLimit(_ limit: Int) {
        self.simultaneouslyLoadingCount = limit

        Task { @MainActor [weak self] in
            await self?.processDownloadQueue()
        }
    }

    func applyReservedSpace(_ plan: ReservedSpace) {
        do {
            try self.storageService.checkEnoughFreeStorage(requiredGB: plan.gigabytes)
            self.reservedSpace = plan
        } catch {
            self.handleError(error)
        }
    }

    func handleBackgroundCompletion(_ handler: @escaping () -> Void) {
        self.networkService.setBackgroundCompletionHandler { [weak self] in
            Task { @MainActor in
                self?.persistDownloadSession(force: true)
                handler()
            }
        }
    }

    func handleDownloadAction(for track: TrackEntity) async {
        switch track.downloadState {
            case .idle:
                await self.startDownload(track)

            case .paused:
                await self.resumeDownload(track: track)

            case .downloading:
                await self.stopDownload(track: track)

            case .completed:
                self.deleteDownloadedTrack(track: track)

            case .queued:
                self.cancelQueuedDownload(track: track)

            case .failed:
                self.error = nil
                await self.startDownload(track)
        }
    }

    // MARK: - Only for testing!!!

    func resetTransferState() async {
        self.cancelLoadTask()

        await self.networkService.cancelAllDownloads()

        self.queuedDownloadTrackIDs.removeAll()
        self.inProgressTrackIDs.removeAll()

        AudioService.shared.stop()
        self.tracks.removeAll()

        do {
            try self.persistenceService.clearStorage()
            try self.storageService.clearStorage()

            self.clearDownloadState()
            self.offset = .zero
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

        self.setupNotificationObservers()
    }

    // MARK: - Properties. Private

    /**
     Private implementation details don't need to be observed from outside.
     Use `@ObservationIgnored` for mutable private properties that should not trigger view updates.
     Note: `@Observable` already skips `let` constants automatically.
     */

    private let limit: Int = 8
    private let networkService: NetworkServicing
    private let persistenceService: PersistenceServicing
    private let storageService: FileManagerServicing
    private let downloadObserverTokens = TransferDownloadObserverTokens()

    @ObservationIgnored
    private var queuedDownloadTrackIDs: [String] = []
    @ObservationIgnored
    private var lastPersistedProgressBytesByTrackID: [String: Int] = [:]
    @ObservationIgnored
    private var loadTask: Task<Void, Never>?
    @ObservationIgnored
    private var isProcessingDownloadQueue = false
    @ObservationIgnored
    private var pendingDownloadQueuePass = false

    private let progressPersistStepBytes = 65_536
    private let estimatedTrackSizeFallback: Int = 10 * 1024 * 1024

    private var hasFreeDownloadSlot: Bool {
        self.inProgressTrackIDs.count < self.simultaneouslyLoadingCount
    }

    // MARK: - Methods. Private

    private func cancelLoadTask() {
        self.loadTask?.cancel()
        self.loadTask = nil
    }

    private func loadInitialTracks() async throws {
        self.offset = .zero

        let loadedTracks = await self.loadTracks(offset: 0)
        try Task.checkCancellation()

        self.tracks = loadedTracks
        self.offset = loadedTracks.count
    }

    private func restoreFromPersistedState(_ entities: [TrackEntity]) async {
        self.tracks = entities

        self.seedPersistedProgressBaseline()

        await self.networkService.restoreDownloadSession()
        await self.networkService.waitForPendingCancellations(timeout: 2.5)
        await self.restoreInterruptedDownloads()
        await self.processDownloadQueue()
    }

    private func loadTracks(offset: Int) async -> [TrackEntity] {
        do {
            let dtos = try await self.networkService.getPopularTracks(
                limit: self.limit,
                offset: offset
            )

            let entities = dtos.map(TrackEntity.init)

            do {
                try self.persistenceService.insert(tracks: entities)
            } catch {
                self.handleError(error)
            }

            return entities
        } catch {
            self.handleError(error)

            return []
        }
    }

    private func enqueueDownload(track: TrackEntity) {
        guard self.queuedDownloadTrackIDs.contains(track.id) == false else {
            return
        }

        self.queuedDownloadTrackIDs.append(track.id)
        track.downloadState = .queued
        self.persistDownloadSession()
    }

    private func activateDownload(track: TrackEntity) async {
        self.inProgressTrackIDs.insert(track.id)
        track.downloadState = .downloading
        self.updateProgressBaseline(for: track)
        self.persistDownloadSession()

        do {
            try await self.networkService.startDownload(track)
        } catch {
            await self.handleDownloadActivationFailure(track, error: error)
        }
    }

    private func activateResumeDownload(track: TrackEntity) async {
        self.inProgressTrackIDs.insert(track.id)
        track.downloadState = .downloading
        self.updateProgressBaseline(for: track)
        self.persistDownloadSession()

        do {
            try await self.networkService.resumeDownload(trackId: track.id)
        } catch {
            await self.handleResumeFailure(track, error: error)
        }
    }

    private func handleDownloadActivationFailure(_ track: TrackEntity, error: Error) async {
        self.markDownloadFailed(track: track)
        self.handleError(error)
        await self.finishActiveDownload(trackId: track.id)
    }

    private func handleResumeFailure(_ track: TrackEntity, error: Error) async {
        self.logTransferWarning("Resume failed for \(track.id), restarting from scratch: \(error.localizedDescription)")
        self.networkService.clearPersistedResumeData(trackId: track.id)

        do {
            try await self.networkService.startDownload(track)
        } catch {
            await self.handleDownloadActivationFailure(track, error: error)
        }
    }

    private func finishActiveDownload(trackId: String) async {
        self.inProgressTrackIDs.remove(trackId)
        self.persistDownloadSession()
        await self.processDownloadQueue()
    }

    private func processDownloadQueue() async {
        guard self.isProcessingDownloadQueue == false else {
            self.pendingDownloadQueuePass = true
            return
        }

        self.isProcessingDownloadQueue = true

        defer {
            self.isProcessingDownloadQueue = false
        }

        repeat {
            self.pendingDownloadQueuePass = false

            let runningTrackIDs = await self.networkService.runningDownloadTrackIDs()

            while self.hasFreeDownloadSlot, self.queuedDownloadTrackIDs.isEmpty == false {
                let trackID = self.queuedDownloadTrackIDs.removeFirst()

                guard runningTrackIDs.contains(trackID) == false,
                      self.inProgressTrackIDs.contains(trackID) == false,
                      let track = self.track(byID: trackID),
                      track.downloadState == .queued else {
                    continue
                }

                guard self.hasEnoughFreeSpace(for: track) else {
                    self.resetTrackState(track, to: .idle)
                    continue
                }

                let hasResumeData = await self.networkService.hasPersistedResumeData(trackId: trackID)

                if hasResumeData {
                    await self.activateResumeDownload(track: track)
                } else {
                    await self.activateDownload(track: track)
                }

                self.persistDownloadSession()
            }
        } while self.pendingDownloadQueuePass
    }

    private func restoreInterruptedDownloads() async {
        let liveActive = await self.networkService.runningDownloadTrackIDs()

        for track in self.tracks
        where self.storageService.downloadedTrackExists(id: track.id) {
            track.downloadingSize = track.size ?? track.downloadingSize
            track.downloadState = .completed
            track.fileState = .exists
        }

        var queuedInOrder: [String] = []

        for track in self.tracks
        where track.downloadState == .downloading && liveActive.contains(track.id) {
            self.inProgressTrackIDs.insert(track.id)
        }

        for track in self.tracks
        where track.downloadState == .downloading && liveActive.contains(track.id) == false {
            track.downloadState = .queued
            queuedInOrder.append(track.id)
        }

        let persistedQueue = self.tracks
            .filter { $0.downloadState == .queued }
            .sorted { ($0.downloadQueueIndex ?? .max) < ($1.downloadQueueIndex ?? .max) }

        for track in persistedQueue where queuedInOrder.contains(track.id) == false {
            queuedInOrder.append(track.id)
        }

        self.queuedDownloadTrackIDs = queuedInOrder
        self.persistDownloadSession(force: true)
    }

    private func persistDownloadSession(force: Bool = false) {
        let queuePositionByTrackID = Dictionary(
            uniqueKeysWithValues: self.queuedDownloadTrackIDs.enumerated().map { ($1, $0) }
        )

        var indicesChanged = false

        for track in self.tracks {
            let newPosition = queuePositionByTrackID[track.id]
            if track.downloadQueueIndex != newPosition {
                track.downloadQueueIndex = newPosition
                indicesChanged = true
            }
        }

        guard force || indicesChanged else {
            return
        }

        do {
            try self.persistenceService.save()
        } catch {
            self.handleError(error)
        }
    }

    private func seedPersistedProgressBaseline() {
        for track in self.tracks where track.downloadState == .downloading {
            self.updateProgressBaseline(for: track)
        }
    }

    private func updateProgressBaseline(for track: TrackEntity) {
        self.lastPersistedProgressBytesByTrackID[track.id] = track.downloadingSize
    }

    private func hasEnoughFreeSpace(for track: TrackEntity) -> Bool {
        let size = track.size ?? self.estimatedTrackSizeFallback
        let requiredGB = Double(size) / GlobalConstants.bytesInGigabyte
        let available = self.storageService.getFreeStorage() ?? .zero
        let reserved = self.reservedSpace.gigabytes

        guard available >= requiredGB else {
            let message = "Not enough free space on device"
            self.error = message
            self.logTransferWarning(message)
            return false
        }

        guard (available - requiredGB) >= reserved else {
            let message = "Download would violate reserved space policy (reserved: \(reserved) GB)"
            self.error = message
            self.logTransferWarning(message)
            return false
        }

        return true
    }

    private func applyDownloadProgress(trackID: String, totalBytesWritten: Int64) {
        guard let track = self.track(byID: trackID) else {
            return
        }

        let reportedBytes = Int(min(totalBytesWritten, Int64(Int.max)))
        let displayedBytes = max(track.downloadingSize, reportedBytes)
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

    private func applyDownloadFinished(trackID: String) {
        guard let track = self.track(byID: trackID) else {
            return
        }

        track.downloadingSize = track.size ?? .zero
        track.downloadState = .completed
        track.fileState = .exists

        Task { @MainActor [weak self] in
            await self?.finishActiveDownload(trackId: trackID)
        }
    }

    private func applyDownloadFailed(trackID: String, error: Any) {
        guard let track = self.track(byID: trackID) else {
            return
        }

        self.markDownloadFailed(track: track)

        let resolvedError: Error = {
            if let apiError = error as? AppError.API {
                return apiError
            }
            if let localizedError = error as? Error {
                return localizedError
            }
            return AppError.API.unknown
        }()
        self.handleError(resolvedError)

        Task { @MainActor [weak self] in
            await self?.finishActiveDownload(trackId: trackID)
        }
    }

    private func applyDownloadInterrupted(trackID: String) async {
        self.inProgressTrackIDs.remove(trackID)

        guard let track = self.track(byID: trackID) else {
            self.persistDownloadSession()
            await self.processDownloadQueue()
            return
        }

        if track.downloadState == .paused {
            self.persistDownloadSession()
            await self.processDownloadQueue()
            return
        }

        if self.queuedDownloadTrackIDs.contains(trackID) == false {
            self.queuedDownloadTrackIDs.insert(trackID, at: .zero)
        }
        track.downloadState = .queued

        self.persistDownloadSession()
        await self.processDownloadQueue()
    }

    private func track(byID trackID: String) -> TrackEntity? {
        self.tracks.first { $0.id == trackID }
    }

    private func resetTrackState(
        _ track: TrackEntity,
        to state: DownloadState,
        fileState: FileStorageState? = nil
    ) {
        track.downloadState = state
        track.downloadingSize = .zero

        if let fileState {
            track.fileState = fileState
        }
    }

    private func clearDownloadState() {
        for track in self.tracks {
            self.resetTrackState(track, to: .idle)
        }
    }

    private func markDownloadFailed(track: TrackEntity) {
        self.resetTrackState(track, to: .failed, fileState: FileStorageState.none)
    }

    private func formatBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func logTransferWarning(_ message: String) {
        AppLogger.transfer.warning("\(message)")
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.error = message
        self.logTransferWarning(message)
    }

    private func setupNotificationObservers() {
        let mainQueue = OperationQueue.main

        self.downloadObserverTokens.progressToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadProgress,
            object: nil,
            queue: mainQueue
        ) { [weak self] notification in
            guard
                let trackID: String = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.trackID
                ),
                let trackDownloadedBytes: Int64 = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.totalBytesWritten
                )
            else {
                return
            }

            guard let self else { return }

            Task { @MainActor [self] in

                self.applyDownloadProgress(trackID: trackID, totalBytesWritten: trackDownloadedBytes)

            }
        }

        self.downloadObserverTokens.finishedToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadDidFinish,
            object: nil,
            queue: mainQueue
        ) { [weak self] notification in
            guard
                let trackID: String = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.trackID
                )
            else {
                return
            }

            guard let self else { return }

            Task { @MainActor in
                self.applyDownloadFinished(trackID: trackID)
            }
        }

        self.downloadObserverTokens.failedToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadDidFail,
            object: nil,
            queue: mainQueue
        ) { [weak self] notification in
            guard
                let trackID: String = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.trackID
                ),
                let error: Error = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.error
                )
            else {
                return
            }

            guard let self else { return }

            Task { @MainActor in
                self.applyDownloadFailed(trackID: trackID, error: error)
            }
        }

        self.downloadObserverTokens.interruptedToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadDidInterrupt,
            object: nil,
            queue: mainQueue
        ) { [weak self] notification in
            guard
                let trackID: String = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.trackID
                )
            else {
                return
            }

            Task { @MainActor in
                await self?.applyDownloadInterrupted(trackID: trackID)
            }
        }
    }
}
