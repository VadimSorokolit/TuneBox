//
//  PlayerViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation
import Combine
import Resolver
import Observation

private enum PlaybackDirection {
    case next
    case previous
}

@MainActor
@Observable
final class PlayerViewModel: PlayerManaging {

    // MARK: Properties. Public

    private(set) var playlist: PlaylistEntity?
    private(set) var progress: Double = 0
    private(set) var error: String?

    // MARK: - Initializer

    init() {
        self.audioService.stateChangeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
            }
            .store(in: &self.cancellables)

        self.audioService.progressSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.progress = value
            }
            .store(in: &cancellables)
    }

    // MARK: - Methods. Public

    func loadPlaylist() {
        self.isLoading = true

        defer {
            self.isLoading = false
        }

        if  let playlistID = UserDefaults.standard.string(forKey: GlobalConstants.UserDefaultsKey.playlistID) {
            do {
                if let playlist = try self.persistenceService.getPlaylist(id: playlistID) {
                    self.playlist = playlist
                }
            } catch {
                self.handleError(error)
            }
        }
    }

    func handlePlayAction(for track: TrackEntity) {
        switch track.source {
            case .api:
                do {
                    let url = try FileManagerService.makeDownloadedTrackURL(id: track.id)

                    self.track = track
                    self.audioService.toggle(trackId: track.id, url: url, loop: false)
                } catch {
                    AppLogger.audio.error("Failed to make track URL: \(String(describing: error))")
                }

            case .imported:
                guard let url = self.resolveImportedURL(for: track) else {
                    AppLogger.audio.error("Imported file missing for track: \(track.id)")

                    return
                }

                self.track = track
                self.audioService.toggle(trackId: track.id, url: url, loop: false)
        }
    }

    func resetPlayback() {
        self.audioService.stop()
        self.track = nil
        self.progress = 0
        self.isPlaying = false
    }

    func isPlaying(_ track: TrackEntity) -> Bool {
        self.track?.id == track.id && self.isPlaying
    }

    func playNext() {
        self.playTrack(.next)
    }

    func playPrevious() {
        self.playTrack(.previous)
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

    private func playTrack(_ direction: PlaybackDirection) {
        guard let tracks = self.playlist?.tracks,
              let firstTrack = tracks.first else {
            return
        }

        guard let current = self.track,
              let index = tracks.firstIndex(where: { $0.id == current.id }) else {
            self.handlePlayAction(for: firstTrack)

            return
        }

        let newIndex: Int

        switch direction {
            case .next:
                newIndex = index + 1

            case .previous:
                newIndex = index - 1
        }

        guard tracks.indices.contains(newIndex) else { return }

        self.handlePlayAction(for: tracks[newIndex])
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.error = message
        AppLogger.imported.warning("\(message)")
    }

    private func resolveImportedURL(for track: TrackEntity) -> URL? {
        let ext = track.localFileURL?.pathExtension ?? AudioFileExtension.mp3.rawValue
        guard let url = try? FileManagerService.makeImportedTrackURL(
            id: track.id,
            fileExtension: ext
        ), FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }
}
