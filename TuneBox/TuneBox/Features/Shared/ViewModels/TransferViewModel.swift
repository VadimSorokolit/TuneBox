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

protocol TransferStateProviding: AnyObject {
    var tracks: [Track] { get set }
    var downloadingTrackIDs: Set<String> { get set }
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }

}

protocol TransferStorageStateProviding: AnyObject {
    var availableSpace: Double? { get }
    var reservedSpace: ReservedSpace { get set }
    func applyReservedSpace(_ plan: ReservedSpace)
}

protocol DownloadManaging: AnyObject {
    func getPopularTracks(page: Int, perPage: Int) async
    func startDownload(_ track: Track) async throws
    //    func pauseDownload(trackID: String) async
    //    func resumeDownload(trackID: String) async throws
    //    func cancelDownload(trackID: String) async
}

typealias TransferManaging = TransferStateProviding
                             & TransferStorageStateProviding
                             & DownloadManaging

@MainActor
@Observable
final class TransferViewModel: TransferManaging {

    // MARK: Properties

    var tracks: [Track] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var downloadingTrackIDs: Set<String> = []
    var availableSpace: Double? {
        self.storageService.getFreeStorage()
    }
    var reservedSpace: ReservedSpace = ReservedSpace.oneGB

    let networkService: NetworkServicing
    let storageService: StorageServicing

    // MARK: - Initializer

    init(networkService: NetworkServicing, storageService: StorageServicing) {
        self.networkService = networkService
        self.storageService = storageService
    }

    // MARK: - Methods

    func getPopularTracks(page: Int, perPage: Int) async {
        do {
            let tracks = try await self.networkService.getPopularTracks(page: page, perPage: perPage)
            self.tracks = tracks
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func startDownload(_ track: Track) async {
        if let size = track.size {
            let requiredGB = Double(size) / GlobalConstants.bytesInGigabyte
            let available = self.storageService.getFreeStorage() ?? 0

            guard available >= requiredGB else {
                self.errorMessage = "Not enough free space on device"
                return
            }
        }

        self.downloadingTrackIDs.insert(track.id)
        defer {
            self.downloadingTrackIDs.remove(track.id)
        }

        do {
            _ = try await self.networkService.downloadTrack(track)
            if let index = self.tracks.firstIndex(where: { $0.id == track.id }) {
                self.tracks[index].isDownloaded = true
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func applyReservedSpace(_ plan: ReservedSpace) {
        do {
            try self.storageService.checkEnoughFreeStorage(requiredGB: Double(plan.rawValue))
            self.reservedSpace = plan
            print(reservedSpace.rawValue)
        } catch let error as StorageError {
            self.errorMessage = error.errorDescription
            print(self.errorMessage)
        } catch {
            self.errorMessage = error.localizedDescription
            print(self.errorMessage)
        }
    }
}
