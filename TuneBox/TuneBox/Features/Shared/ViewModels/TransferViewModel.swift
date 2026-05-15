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

protocol TransferStateProviding: AnyObject {
    var tracks: [Track] { get set }
    var downloadingTrackIDs: Set<String> { get set }
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }

}

protocol TransferStorageStateProviding: AnyObject {
    var availableSpace: Double? { get }
    var reservedSpace: ReservedSpace { get set }
    var simultaneouslyLoadingTraks: Int { get set }

    func applyReservedSpace(_ plan: ReservedSpace)
}

protocol DownloadManaging: AnyObject {
    func getPopularTracks(page: Int, perPage: Int) async
    func startDownload(_ track: Track) async throws
    func pauseDownload(trackID: String) async
    func resumeDownload(trackID: String) async throws
    func deleteDownloadedTrack(id: String)
    func deleteAllTracks()
}

protocol TransferManaging: TransferStateProviding, TransferStorageStateProviding, DownloadManaging {}

@MainActor
@Observable
final class TransferViewModel: TransferManaging {

    // MARK: Properties. Public

    var tracks: [Track] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var downloadingTrackIDs: Set<String> = []
    var simultaneouslyLoadingTraks: Int = SimultaneouslyLoadingTraks.two.rawValue
    var reservedSpace: ReservedSpace = ReservedSpace.oneGB

    var availableSpace: Double? {
        self.storageService.getFreeStorage()
    }

    // MARK: - Methods. Public

    func getPopularTracks(page: Int, perPage: Int) async {
        do {
            let tracks = try await self.networkService.getPopularTracks(page: page, perPage: perPage)
            self.tracks = tracks
        } catch {
            let message = error.localizedDescription
            self.errorMessage = message
            self.logTransferWarning(message)
        }
    }

    func startDownload(_ track: Track) async throws {
        if let size = track.size {
            let requiredGB = Double(size) / GlobalConstants.bytesInGigabyte
            let available = self.storageService.getFreeStorage() ?? 0

            guard available >= requiredGB else {
                let message = "Not enough free space on device"
                self.errorMessage = message
                self.logTransferWarning(message)
                return
            }
        }

        self.downloadingTrackIDs.insert(track.id)
        defer {
            self.downloadingTrackIDs.remove(track.id)
        }

        if let index = self.tracks.firstIndex(where: { $0.id == track.id }) {
            self.tracks[index].downloadingSize = 0
        }

        do {
            _ = try await self.networkService.downloadTrack(track)
            if let index = self.tracks.firstIndex(where: { $0.id == track.id }) {
                self.tracks[index].isDownloaded = true
                self.tracks[index].downloadingSize = 0
            }
        } catch {
            if let index = self.tracks.firstIndex(where: { $0.id == track.id }) {
                self.tracks[index].downloadingSize = 0
            }
            let message = error.localizedDescription
            self.errorMessage = message
            self.logTransferWarning(message)
            throw error
        }
    }

    func pauseDownload(trackID: String) async {
        await self.networkService.stopDownload(trackID: trackID)

        if let track = self.tracks.first(where: { $0.id == trackID }) {
            let bytes = track.downloadingSize
            let readable = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            AppLogger.transfer.info("Paused track \(trackID): \(readable) (\(bytes) B)")
        }
    }

    func resumeDownload(trackID: String) async throws {
        if let track = self.tracks.first(where: { $0.id == trackID }), let size = track.size {
            let requiredGB = Double(size) / GlobalConstants.bytesInGigabyte
            let available = self.storageService.getFreeStorage() ?? 0

            guard available >= requiredGB else {
                let message = "Not enough free space on device"
                self.errorMessage = message
                self.logTransferWarning(message)
                return
            }
        }

        try await self.networkService.resumeDownload(trackID: trackID)
    }

    func deleteDownloadedTrack(id: String) {
        do {
            try self.storageService.deleteDownloadedTrack(id: id)
        } catch {
            let message = error.localizedDescription
            self.errorMessage = message
            self.logTransferWarning(message)
        }
    }

    func deleteAllTracks() {
        do {
            try self.storageService.deleteAllTracks()
        } catch {
            let message = error.localizedDescription
            self.errorMessage = message
            self.logTransferWarning(message)
        }
    }

    func setSimultaneouslyLoadingLimit(_ limit: Int) {
        self.simultaneouslyLoadingTraks = limit
    }

    func applyReservedSpace(_ plan: ReservedSpace) {
        do {
            try self.storageService.checkEnoughFreeStorage(requiredGB: Double(plan.rawValue))
            self.reservedSpace = plan
        } catch let storageError as StorageError {
            let message = storageError.errorDescription ?? storageError.localizedDescription
            self.errorMessage = message
            self.logTransferWarning(message)
        } catch {
            let message = error.localizedDescription
            self.errorMessage = message
            self.logTransferWarning(message)
        }
    }

    // MARK: - Initializer

    init(networkService: NetworkServicing, storageService: StorageServicing) {
        self.networkService = networkService
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

    private let networkService: NetworkServicing
    private let storageService: StorageServicing
    private let downloadObserverTokens = TransferDownloadObserverTokens()

    // MARK: - Methods. Private

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
}

private final class TransferDownloadObserverTokens: @unchecked Sendable {
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
