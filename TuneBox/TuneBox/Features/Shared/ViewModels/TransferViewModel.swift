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
    func deleteAllTracks()
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
        let currentTrack = self.tracks.first(where: { $0.id == track.id }) ?? track

        guard self.checkFreeStorageSpace(for: currentTrack) else {
            return
        }

        if currentTrack.downloadingSize != 0 {
            await self.resumeDownload(trackId: currentTrack.id)
            return
        }

        await self.performDownload(trackId: track.id) {
            _ = try await self.networkService.downloadTrack(track)

            if let index = self.tracks.firstIndex(where: { $0.id == track.id }) {
                self.tracks[index].isDownloaded = true
                try self.persistenceService.upsert(track: TrackEntity(track: self.tracks[index]))
            }
        }
    }

    func stopDownload(trackId: String) async {
        await self.networkService.stopDownload(trackId: trackId)

        if let track = self.tracks.first(where: { $0.id == trackId }) {
            do {
                try self.persistenceService.upsert(track: TrackEntity(track: track))
            } catch {
                self.handleError(error)
            }

            let bytes = track.downloadingSize
            let readable = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            self.logTransferWarning("Paused track \(trackId): \(readable) (\(bytes) B)")
        }
    }

    func resumeDownload(trackId: String) async {
        let track = self.tracks.first(where: { $0.id == trackId })

        if let track, self.checkFreeStorageSpace(for: track) == false {
            return
        }

        await self.performDownload(trackId: trackId) {
            try await self.networkService.resumeDownload(trackId: trackId)
        }
    }

    func deleteDownloadedTrack(id: String) {
        do {
            try self.storageService.deleteDownloadedTrack(id: id)

            if let index = self.tracks.firstIndex(where: { $0.id == id }) {
                self.tracks[index].isDownloaded = false
            }

            if let entity = self.getTrack(id: id) {
                entity.isRemoved = true
                try self.persistenceService.upsert(track: entity)
            } else if let index = self.tracks.firstIndex(where: { $0.id == id }) {
                try self.persistenceService.upsert(track: TrackEntity(track: self.tracks[index]))
            }
        } catch {
            self.handleError(error)
        }
    }

    // MARK: - Only for testing!!!

    func deleteAllTracks() {
        do {
            _  = try persistenceService.clearStorage()
            do {
                try self.storageService.clearStorage()
            } catch {
                self.handleError(error)
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
            guard let trackID = notification.userInfo?["trackID"] as? String else {
                return
            }

            Task { @MainActor [weak self, trackID] in
                guard let self else { return }
                self.applyDownloadFinished(trackID: trackID)
            }
        }
    }

    // MARK: - Properties. Private

    let perPage: Int = 20
    private let networkService: NetworkServicing
    private let persistenceService: PersistenceServicing
    private let storageService: FileManagerServicing
    private let downloadSlotLimiter = TransferDownloadSlotLimiter()
    private let downloadObserverTokens = TransferDownloadObserverTokens()

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

    private func performDownload(
        trackId: String,
        operation: () async throws -> Void
    ) async {
        await self.downloadSlotLimiter.acquire(limit: self.simultaneouslyLoadingTraks)

        defer {
            self.downloadSlotLimiter.release()
        }

        self.downloadingTrackIds.insert(trackId)

        defer {
            self.downloadingTrackIds.remove(trackId)
        }

        do {
            try await operation()
        } catch {
            self.handleError(error)
        }
    }

    private func checkFreeStorageSpace(for track: Track) -> Bool {
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

    private func getTrack(id: String) -> TrackEntity? {
        do {
            return try self.persistenceService.getTrack(id: id)
        } catch {
            self.handleError(error)
            return nil
        }
    }

    private func applyDownloadProgress(trackID: String, totalBytesWritten: Int64) {
        guard let index = self.tracks.firstIndex(where: { $0.id == trackID }) else {
            return
        }

        self.tracks[index].downloadingSize = Int(min(totalBytesWritten, Int64(Int.max)))
    }

    private func applyDownloadFinished(trackID: String) {
        guard let index = self.tracks.firstIndex(where: { $0.id == trackID }) else {
            return
        }

        self.tracks[index].downloadingSize = 0
    }

    private func logTransferWarning(_ message: String) {
        AppLogger.transfer.warning("\(message)")
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.errorMessage = message
        self.logTransferWarning(message)
    }
}
