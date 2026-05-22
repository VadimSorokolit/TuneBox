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
    func startDownload(_ track: Track) async throws
    func stopDownload(trackId: String) async
    func resumeDownload(trackId: String) async
    func cancelQueuedDownload(trackId: String)
    func deleteDownloadedTrack(id: String)
}

protocol TransferPersistenceServicing: AnyObject {
//    func fetchEntities() throws -> [TrackEntity]
//    func upsert(entity: TrackEntity) throws
//    func deleteEntity(id: String) throws
//    func deleteAllEntities() throws
}

protocol TransferStateProviding: AnyObject {
    var page: Int { get set }
    var tracks: [Track] { get set }
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
    func startDownload(_ track: Track) async
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
    var tracks: [Track] = []
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
                try await self.loadTracks(page: 0)
            } else {
                self.tracks = entities.map { Track(entity: $0) }
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

        do {
            try await self.loadTracks(page: self.page + 1)
        } catch {
            self.handleError(error)
        }
    }

    func startDownload(_ track: Track) async {
        guard let index = self.tracks.firstIndex(where: { $0.id == track.id }) else {
            return
        }

        guard self.hasEnoughFreeSpace(for: self.tracks[index]) else {
            return
        }

        if self.tracks[index].downloadingSize != 0 {
            await self.resumeDownload(trackId: self.tracks[index].id)
            return
        }

        if self.hasFreeDownloadSlot == false {
            self.enqueueDownload(trackId: track.id, at: index)
            return
        }

        await self.activateDownload(track: self.tracks[index], at: index)
    }

    func stopDownload(trackId: String) async {
        await self.networkService.stopDownload(trackId: trackId)
        await self.finishActiveDownload(trackId: trackId)

        if let index = self.tracks.firstIndex(where: { $0.id == trackId }) {
            self.tracks[index].downloadState = .paused
            self.tracks[index].fileState = .exists

            do {
                try self.persistenceService.upsert(track: TrackEntity(track: self.tracks[index]))
            } catch {
                self.handleError(error)
            }

            let bytes = self.tracks[index].downloadingSize
            let readable = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            self.logTransferWarning("Paused track \(trackId): \(readable) (\(bytes) B)")
        }
    }

    func resumeDownload(trackId: String) async {
        guard let index = self.tracks.firstIndex(where: { $0.id == trackId }) else {
            return
        }

        guard self.hasEnoughFreeSpace(for: self.tracks[index]) else {
            return
        }

        if self.hasFreeDownloadSlot == false {
            self.enqueueDownload(trackId: trackId, at: index)
            return
        }

        await self.activateResumeDownload(track: self.tracks[index], at: index)
    }

    func cancelQueuedDownload(trackId: String) {
        guard let index = self.tracks.firstIndex(where: { $0.id == trackId }) else {
            return
        }

        guard self.tracks[index].downloadState == .queued else {
            return
        }

        self.downloadQueue.removeAll { $0 == trackId }
        self.tracks[index].downloadState = .idle
        self.tracks[index].fileState = .none
        self.tracks[index].downloadingSize = 0

        self.persistTrack(at: index)
        self.persistDownloadSession()
    }

    func saveTransferState() {
        for index in self.tracks.indices {
            switch self.tracks[index].downloadState {
                case .downloading, .queued:
                    self.persistTrack(at: index)

                case .idle, .paused, .completed, .failed:
                    break
            }
        }

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

            guard let index = self.tracks.firstIndex(where: { $0.id == trackID }) else {
                continue
            }

            if self.tracks[index].downloadState != .downloading {
                self.tracks[index].downloadState = .downloading
                self.persistTrack(at: index)
            }
        }

        await self.processDownloadQueue()
    }

    func deleteDownloadedTrack(id: String) {
        self.networkService.clearPersistedResumeData(trackId: id)

        do {
            try self.storageService.deleteDownloadedTrack(id: id)

            if let index = self.tracks.firstIndex(where: { $0.id == id }) {
                self.tracks[index].downloadState = .idle
                self.tracks[index].fileState = .removed
                self.tracks[index].downloadingSize = 0
            }

            if let entity = self.getTrack(id: id) {
                entity.downloadState = DownloadState.idle.rawValue
                entity.fileState = FileStorageState.removed.rawValue
                entity.downloadingSize = 0
                try self.persistenceService.upsert(track: entity)
            } else if let index = self.tracks.firstIndex(where: { $0.id == id }) {
                try self.persistenceService.upsert(track: TrackEntity(track: self.tracks[index]))
            }
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
            _ = try persistenceService.clearStorage()

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

    private func loadTracks(page: Int) async throws {
        let tracks = try await self.networkService.getPopularTracks(
            page: page,
            perPage: self.perPage
        )

        self.tracks.append(contentsOf: tracks)
        self.page = page

        for track in tracks {
            do {
                try self.persistenceService.upsert(track: TrackEntity(track: track))
            } catch {
                self.handleError(error)
            }
        }
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

        for index in self.tracks.indices {
            let trackID = self.tracks[index].id

            if self.storageService.downloadedTrackExists(id: trackID) {
                self.tracks[index].downloadingSize = self.tracks[index].size ?? self.tracks[index].downloadingSize
                self.tracks[index].downloadState = .completed
                self.tracks[index].fileState = .exists
                self.persistTrack(at: index)
            }
        }

        var queuedInOrder: [String] = []

        for trackID in savedSession.activeTrackIDs {
            guard let index = self.tracks.firstIndex(where: { $0.id == trackID }) else {
                continue
            }

            if self.tracks[index].downloadState == .completed {
                continue
            }

            if liveActive.contains(trackID) {
                self.downloadingTrackIds.insert(trackID)
                self.registerActiveDownload(trackID)
                self.tracks[index].downloadState = .downloading
                self.persistTrack(at: index)
                continue
            }

            self.tracks[index].downloadState = .queued
            self.persistTrack(at: index)
            queuedInOrder.append(trackID)
        }

        for trackID in savedSession.queuedTrackIDs where queuedInOrder.contains(trackID) == false {
            guard let index = self.tracks.firstIndex(where: { $0.id == trackID }) else {
                continue
            }

            if self.tracks[index].downloadState == .completed {
                continue
            }

            self.tracks[index].downloadState = .queued
            self.persistTrack(at: index)
            queuedInOrder.append(trackID)
        }

        for index in self.tracks.indices where self.tracks[index].downloadState == .queued {
            let trackID = self.tracks[index].id
            if queuedInOrder.contains(trackID) == false {
                queuedInOrder.append(trackID)
            }
        }

        for index in self.tracks.indices where self.tracks[index].downloadState == .downloading {
            let trackID = self.tracks[index].id

            if liveActive.contains(trackID) {
                continue
            }

            self.tracks[index].downloadState = .queued
            self.persistTrack(at: index)

            if queuedInOrder.contains(trackID) == false {
                queuedInOrder.insert(trackID, at: 0)
            }
        }

        self.downloadQueue = queuedInOrder
        self.persistDownloadSession()
    }

    private func clearDownloadState() {
        for index in self.tracks.indices {
            self.tracks[index].downloadingSize = 0
            self.tracks[index].downloadState = .idle
        }
    }

    private func seedPersistedProgressBaseline() {
        for track in self.tracks where track.downloadState == .downloading {
            self.lastPersistedProgressBytesByTrackID[track.id] = track.downloadingSize
        }
    }

    private func enqueueDownload(trackId: String, at index: Int) {
        guard self.downloadQueue.contains(trackId) == false else {
            return
        }

        self.downloadQueue.append(trackId)
        self.tracks[index].downloadState = .queued
        self.persistTrack(at: index)
        self.persistDownloadSession()
    }

    private func activateDownload(track: Track, at index: Int) async {
        self.downloadingTrackIds.insert(track.id)
        self.registerActiveDownload(track.id)
        self.tracks[index].downloadState = .downloading
        self.lastPersistedProgressBytesByTrackID[track.id] = self.tracks[index].downloadingSize
        self.persistTrack(at: index)
        self.persistDownloadSession()

        do {
            try await self.networkService.startDownload(track)
        } catch {
            self.markDownloadFailed(trackId: track.id)
            self.handleError(error)
            await self.finishActiveDownload(trackId: track.id)
        }
    }

    private func activateResumeDownload(track: Track, at index: Int) async {
        self.downloadingTrackIds.insert(track.id)
        self.registerActiveDownload(track.id)
        self.tracks[index].downloadState = .downloading
        self.lastPersistedProgressBytesByTrackID[track.id] = self.tracks[index].downloadingSize
        self.persistTrack(at: index)
        self.persistDownloadSession()

        do {
            try await self.networkService.resumeDownload(trackId: track.id)
        } catch {
            self.logTransferWarning("Resume failed for \(track.id), restarting from scratch: \(error.localizedDescription)")
            self.networkService.clearPersistedResumeData(trackId: track.id)

            do {
                try await self.networkService.startDownload(track)
            } catch {
                self.markDownloadFailed(trackId: track.id)
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

            guard let index = self.tracks.firstIndex(where: { $0.id == trackId }) else {
                continue
            }

            guard self.tracks[index].downloadState == .queued else {
                continue
            }

            guard self.hasEnoughFreeSpace(for: self.tracks[index]) else {
                self.tracks[index].downloadState = .idle
                self.persistTrack(at: index)
                continue
            }

            let hasResumeData = await self.networkService.hasPersistedResumeData(trackId: trackId)

            if hasResumeData {
                await self.activateResumeDownload(track: self.tracks[index], at: index)
            } else {
                await self.activateDownload(track: self.tracks[index], at: index)
            }
        }

        self.persistDownloadSession()
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

    private func persistTrack(at index: Int) {
        do {
            try self.persistenceService.upsert(track: TrackEntity(track: self.tracks[index]))
        } catch {
            self.handleError(error)
        }
    }

    private func hasEnoughFreeSpace(for track: Track) -> Bool {
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
        guard let index = self.tracks.firstIndex(where: { $0.id == trackID }) else {
            return
        }

        let reportedBytes = Int(min(totalBytesWritten, Int64(Int.max)))
        let previousBytes = self.tracks[index].downloadingSize
        let displayedBytes = max(previousBytes, reportedBytes)

        self.tracks[index].downloadingSize = displayedBytes

        guard self.tracks[index].downloadState == .downloading else {
            return
        }

        let lastPersisted = self.lastPersistedProgressBytesByTrackID[trackID] ?? 0
        let shouldPersist = displayedBytes - lastPersisted >= self.progressPersistStepBytes
            || displayedBytes == self.tracks[index].size

        guard shouldPersist else {
            return
        }

        self.persistTrack(at: index)
        self.lastPersistedProgressBytesByTrackID[trackID] = displayedBytes
    }

    private func applyDownloadFinished(trackID: String) {
        guard let index = self.tracks.firstIndex(where: { $0.id == trackID }) else {
            return
        }

        self.tracks[index].downloadingSize = self.tracks[index].size ?? 0
        self.tracks[index].downloadState = .completed
        self.tracks[index].fileState = .exists

        do {
            try self.persistenceService.upsert(track: TrackEntity(track: self.tracks[index]))
        } catch {
            self.handleError(error)
        }

        Task {
            await self.finishActiveDownload(trackId: trackID)
        }
    }

    private func applyDownloadFailed(trackID: String, error: Any) {
        self.markDownloadFailed(trackId: trackID)

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

    private func applyDownloadInterrupted(trackID: String) async {
        self.downloadingTrackIds.remove(trackID)
        self.unregisterActiveDownload(trackID)

        guard let index = self.tracks.firstIndex(where: { $0.id == trackID }) else {
            self.persistDownloadSession()
            await self.processDownloadQueue()
            return
        }

        if self.tracks[index].downloadState == .paused {
            self.persistDownloadSession()
            await self.processDownloadQueue()
            return
        }

        if self.downloadQueue.contains(trackID) == false {
            self.downloadQueue.insert(trackID, at: 0)
        }

        self.tracks[index].downloadState = .queued
        self.persistTrack(at: index)
        self.persistDownloadSession()

        await self.processDownloadQueue()
    }

    private func logTransferWarning(_ message: String) {
        AppLogger.transfer.warning("\(message)")
    }

    private func markDownloadFailed(trackId: String) {
        guard let index = self.tracks.firstIndex(where: { $0.id == trackId }) else {
            return
        }

        self.tracks[index].downloadState = .failed
        self.tracks[index].fileState = .none
        self.tracks[index].downloadingSize = 0

        self.persistTrack(at: index)
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.errorMessage = message
        self.logTransferWarning(message)
    }
}
