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

enum SimultaneouslyLoadingTraks: Int {
    case two = 2
    case three = 3
    case four = 4
    case five = 5
}

protocol TransferDownloadManaging: AnyObject {
    func startDownload(_ track: TrackEntity) async
    func stopDownload(track: TrackEntity) async
    func resumeDownload(track: TrackEntity) async
    func cancelQueuedDownload(track: TrackEntity)
    func deleteDownloadedTrack(track: TrackEntity)
}

protocol TransferPersistenceServicing: AnyObject {
//    func fetchEntities() throws -> [TrackEntity]
//    func upsert(entity: TrackEntity) throws
//    func deleteEntity(id: String) throws
//    func deleteAllEntities() throws
}

protocol TransferStateProviding: AnyObject {
    var page: Int { get set }
    var tracks: [TrackEntity] { get set }
    var downloadingTrackIds: Set<String> { get set }
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
}

protocol TransferStorageStateProviding: AnyObject {
    var availableSpace: Double? { get }
    var reservedSpace: ReservedSpace { get set }
    var simultaneouslyLoadingTraks: Int { get set }

    func applyReservedSpace(_ plan: ReservedSpace)
}

protocol TransferManaging:
    TransferDownloadManaging,
    TransferStateProviding,
    TransferStorageStateProviding,
    TransferPersistenceServicing {
    func loadFirst() async
    func loadNext() async
    func startDownload(_ track: TrackEntity) async
    func resetTransferState()
    func saveTransferState()
    func snapshotForTerminate() async
    func restoreDownloadsOnForeground() async
}

@MainActor
@Observable
final class TransferViewModel: TransferManaging {

    // MARK: Properties. Public

    var page: Int = 0
    var tracks: [TrackEntity] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var downloadingTrackIds: Set<String> = []
    var simultaneouslyLoadingTraks: Int = SimultaneouslyLoadingTraks.two.rawValue
    var reservedSpace: ReservedSpace = ReservedSpace.oneGB

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
                self.tracks = await self.loadTracks(page: 0)
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

        let newEntityTracks = await self.loadTracks(page: self.page + 1)
        self.tracks.append(contentsOf: newEntityTracks)
    }

    func startDownload(_ track: TrackEntity) async {
        guard self.hasEnoughFreeSpace(for: track) else {
            return
        }

        if track.downloadingSize != 0 {
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

        track.downloadState = DownloadState.paused.rawValue
        track.fileState = FileStorageState.exists.rawValue

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
        guard track.downloadState == DownloadState.queued.rawValue else {
            return
        }

        self.downloadQueue.removeAll { $0 == track.id }
        track.downloadState = DownloadState.idle.rawValue
        track.fileState = FileStorageState.none.rawValue
        track.downloadingSize = 0

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
            self.downloadingTrackIds.insert(trackID)
            self.registerActiveDownload(trackID)

            if let track = self.tracks.first(where: { $0.id == trackID }) {
                if track.downloadState != DownloadState.downloading.rawValue {
                    track.downloadState = DownloadState.downloading.rawValue
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
            track.downloadState = DownloadState.idle.rawValue
            track.fileState = FileStorageState.removed.rawValue
            track.downloadingSize = 0
        } catch {
            self.handleError(error)
        }
    }

    func setSimultaneouslyLoadingLimit(_ limit: Int) {
        self.simultaneouslyLoadingTraks = limit
    }

    func applyReservedSpace(_ plan: ReservedSpace) {
        do {
            try self.storageService.checkEnoughFreeStorage(requiredGB: Double(plan.rawValue))
            self.reservedSpace = plan
        } catch let error as FileManagerError {
            self.handleError(error)
        } catch {
            self.handleError(error)
        }
    }

    // MARK: - Only for testing!!!

    func resetTransferState() {
        Task {
            await self.networkService.cancelAllDownloads()
        }

        self.downloadQueue.removeAll()
        self.activeDownloadOrder.removeAll()
        self.downloadingTrackIds.removeAll()
        self.tracks.removeAll()

        TransferQueueStorage.clear()

        do {
            try self.persistenceService.clearStorage()

            do {
                try self.storageService.clearStorage()
                self.clearDownloadState()
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
                let trackID = notification.userInfo?[TrackDownloadNotificationUserInfoKey.trackID] as? String,
                let written = notification.userInfo?[TrackDownloadNotificationUserInfoKey.totalBytesWritten] as? Int64
            else {
                return
            }

            Task { @MainActor [weak self, trackID, written] in
                guard let self else { return }
                self.applyDownloadProgress(trackID: trackID, totalBytesWritten: written)
            }
        }

        self.downloadObserverTokens.finishedToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadDidFinish,
            object: nil,
            queue: mainQueue
        ) { notification in
            guard let trackID = notification.userInfo?[TrackDownloadNotificationUserInfoKey.trackID] as? String else {
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
                let trackID = notification.userInfo?[TrackDownloadNotificationUserInfoKey.trackID] as? String,
                let error = notification.userInfo?[TrackDownloadNotificationUserInfoKey.error]
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
                let trackID = notification.userInfo?[TrackDownloadNotificationUserInfoKey.trackID] as? String
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

    private let perPage: Int = 8
    private let networkService: NetworkServicing
    private let persistenceService: PersistenceServicing
    private let storageService: FileManagerServicing
    private let downloadObserverTokens = TransferDownloadObserverTokens()
    private var downloadQueue: [String] = []
    private var activeDownloadOrder: [String] = []
    private var lastPersistedProgressBytesByTrackID: [String: Int] = [:]
    private let progressPersistStepBytes = 65_536

    // MARK: - Methods. Private

    private func loadTracks(page: Int) async -> [TrackEntity] {
        do {
            let dtos = try await self.networkService.getPopularTracks(
                page: page,
                perPage: self.perPage
            )
            self.page = page

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
        self.downloadingTrackIds.count < self.simultaneouslyLoadingTraks
    }

    private func restoreInterruptedDownloads() async {
        let liveActive = await self.networkService.runningDownloadTrackIDs()
        let savedSession = TransferQueueStorage.load()

        for track in self.tracks
        where self.storageService.downloadedTrackExists(id: track.id) {
            track.downloadingSize = track.size ?? track.downloadingSize
            track.downloadState = DownloadState.completed.rawValue
            track.fileState = FileStorageState.exists.rawValue
        }

        var queuedInOrder: [String] = []

        for trackID in savedSession.activeTrackIDs {
            if let track = self.tracks.first(where: { $0.id == trackID }) {
                if track.downloadState == DownloadState.completed.rawValue {
                    continue
                }

                if liveActive.contains(trackID) {
                    self.downloadingTrackIds.insert(trackID)
                    self.registerActiveDownload(trackID)
                    track.downloadState = DownloadState.downloading.rawValue

                    continue
                }

                track.downloadState = DownloadState.queued.rawValue
                queuedInOrder.append(trackID)
            } else {
                continue
            }
        }

        for trackID in savedSession.queuedTrackIDs where queuedInOrder.contains(trackID) == false {
            if let track = self.tracks.first(where: { $0.id == trackID }) {
                if track.downloadState == DownloadState.completed.rawValue {
                    continue
                }

                track.downloadState = DownloadState.queued.rawValue

                queuedInOrder.append(trackID)
            } else {
                continue
            }
        }

        for track in self.tracks
        where track.downloadState == DownloadState.queued.rawValue {

            if queuedInOrder.contains(track.id) == false {
                queuedInOrder.append(track.id)
            }
        }

        for track in self.tracks
        where track.downloadState == DownloadState.downloading.rawValue {
            if liveActive.contains(track.id) {
                continue
            }

            track.downloadState = DownloadState.queued.rawValue

            if queuedInOrder.contains(track.id) == false {
                queuedInOrder.insert(track.id, at: 0)
            }
        }

        self.downloadQueue = queuedInOrder
        self.persistDownloadSession()
    }

    private func clearDownloadState() {
        for track in self.tracks {
            track.downloadingSize = 0
            track.downloadState = DownloadState.idle.rawValue
        }
    }

    private func seedPersistedProgressBaseline() {
        for track in self.tracks where track.downloadState == DownloadState.downloading.rawValue {
            self.lastPersistedProgressBytesByTrackID[track.id] = track.downloadingSize
        }
    }

    private func enqueueDownload(track: TrackEntity) {
        guard self.downloadQueue.contains(track.id) == false else {
            return
        }

        self.downloadQueue.append(track.id)
        track.downloadState = DownloadState.queued.rawValue
        self.persistDownloadSession()
    }

    private func activateDownload(track: TrackEntity) async {
        self.downloadingTrackIds.insert(track.id)
        self.registerActiveDownload(track.id)
        track.downloadState = DownloadState.downloading.rawValue
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
        self.downloadingTrackIds.insert(track.id)
        self.registerActiveDownload(track.id)
        track.downloadState = DownloadState.downloading.rawValue
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
        self.downloadingTrackIds.remove(trackId)
        self.unregisterActiveDownload(trackId)
        self.persistDownloadSession()
        await self.processDownloadQueue()
    }

    private func processDownloadQueue() async {
        while self.hasFreeDownloadSlot, self.downloadQueue.isEmpty == false {
            let trackId = self.downloadQueue.removeFirst()

            if let track = self.tracks.first(where: { $0.id == trackId }) {
                guard track.downloadState == DownloadState.queued.rawValue else {
                    continue
                }

                guard self.hasEnoughFreeSpace(for: track) else {
                    track.downloadState = DownloadState.idle.rawValue

                    continue
                }

                let hasResumeData = await self.networkService.hasPersistedResumeData(trackId: trackId)

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
        let available = self.storageService.getFreeStorage() ?? 0

        guard available >= requiredGB else {
            let message = "Not enough free space on device"
            self.errorMessage = message
            self.logTransferWarning(message)
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

            guard track.downloadState == DownloadState.downloading.rawValue else {
                return
            }

            let lastPersisted = self.lastPersistedProgressBytesByTrackID[trackID] ?? 0
            let shouldPersist = displayedBytes - lastPersisted >= self.progressPersistStepBytes
            || displayedBytes == track.size

            guard shouldPersist else {
                return
            }

            self.lastPersistedProgressBytesByTrackID[trackID] = displayedBytes
        }
    }

    private func applyDownloadFinished(trackID: String) {
        if let track = self.tracks.first(where: { $0.id == trackID }) {
            track.downloadingSize = track.size ?? 0
            track.downloadState = DownloadState.completed.rawValue
            track.fileState = FileStorageState.exists.rawValue

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
        self.downloadingTrackIds.remove(trackID)
        self.unregisterActiveDownload(trackID)

        if let track = self.tracks.first(where: { $0.id == trackID }) {
            if track.downloadState == DownloadState.paused.rawValue {
                self.persistDownloadSession()
                await self.processDownloadQueue()
                return
            }

            if self.downloadQueue.contains(trackID) == false {
                self.downloadQueue.insert(trackID, at: 0)
            }

            track.downloadState = DownloadState.queued.rawValue

            self.persistDownloadSession()

            await self.processDownloadQueue()
        } else {
            self.persistDownloadSession()
            await self.processDownloadQueue()

            return
        }
    }

    private func logTransferWarning(_ message: String) {
        AppLogger.transfer.warning("\(message)")
    }

    private func markDownloadFailed(track: TrackEntity) {
        track.downloadState = DownloadState.failed.rawValue
        track.fileState = FileStorageState.none.rawValue
        track.downloadingSize = 0
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.errorMessage = message
        self.logTransferWarning(message)
    }
}
