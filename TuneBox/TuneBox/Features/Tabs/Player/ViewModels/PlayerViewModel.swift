//
//  PlayerViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation
import Combine
import Resolver

@Observable
final class PlayerViewModel: PlayerManaging {

    // MARK: Properties. Public

    private(set) var tracks: [TrackEntity] = []
    private(set) var error: String?

    // MARK: - Initializer

    init() {
        self.audioService.stateChangeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Methods. Public

    func loadPlaylist() {
        self.isLoading = true

        defer {
            self.isLoading = false
        }

        if  let playlistID = UserDefaults.standard.string(forKey: GlobalConstants.UserDefaultsKey.playlistID) {
            do {
                if let playlist = try self.persistenceService.getPlaylist(ID: playlistID) {
                    self.tracks = playlist.tracks
                    print(self.tracks.count)
                }
            } catch {
                self.handleError(error)
            }
        }
    }

    func handlePlayAction(for track: TrackEntity) {
        do {
            let url = try FileManagerService.makeDownloadedTrackURL(id: track.id)

            self.track = track
            self.audioService.toggle(trackId: track.id, url: url, loop: false)
        } catch {
            AppLogger.audio.error("Failed to make track URL: \(String(describing: error))")
        }
    }

    func isPlaying(_ track: TrackEntity) -> Bool {
        self.track?.id == track.id && self.isPlaying
    }

    // MARK: - Properties. Private

    @Injected
    @ObservationIgnored
    private var persistenceService: PersistenceServicing
    private let audioService = AudioService.shared
    private var isLoading: Bool = false
    private var isPlaying = false
    private var track: TrackEntity?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Methods. Private

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.error = message
        AppLogger.imported.warning("\(message)")
    }
}
