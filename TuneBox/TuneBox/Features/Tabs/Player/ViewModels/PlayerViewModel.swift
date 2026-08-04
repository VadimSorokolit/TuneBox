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

enum RepeatMode: String, CaseIterable {
    case off
    case one
    case all
}

@MainActor
@Observable
final class PlayerViewModel: PlayerManaging {

    // MARK: Properties. Public

    private(set) var track: TrackEntity?
    private(set) var playlist: PlaylistEntity?
    private(set) var repeatMode: RepeatMode = .off
    private(set) var progress: Double = 0
    private(set) var isShuffleEnabled = false
    private(set) var isPlaying = false
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

        self.audioService.onRemotePlayNext = { [weak self] in
            Task { @MainActor in
                self?.playNext()
            }
        }
        self.audioService.onRemotePlayPrevious = { [weak self] in
            Task { @MainActor in
                self?.playPrevious()
            }
        }
        self.audioService.onTrackFinished = { [weak self] in
            Task { @MainActor in
                self?.handleTrackFinished()
            }
        }
        self.repeatMode = RepeatMode(
            rawValue: UserDefaults.standard.string(
                forKey: Keys.repeatMode
            ) ?? ""
        ) ?? .off
        self.isShuffleEnabled = UserDefaults.standard.bool(
            forKey: Keys.shuffleEnabled
        )
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

    func handlePlayAction(for track: TrackEntity, in queue: [TrackEntity]) {
        let tracks = queue.isEmpty ? [track] : queue
        let queueChanged = self.playlist?.tracks.map(\.id) != tracks.map(\.id)
        self.playlist = PlaylistEntity(title: "Queue", tracks: tracks)

        if self.isShuffleEnabled, queueChanged || self.shuffleOrder == nil {
            self.rebuildShuffleOrder(startingWith: track)
        }

        if self.track?.id == track.id {
            self.toggle(track)
        } else {
            self.play(track)
        }
    }

    func seek(by deltaSeconds: TimeInterval) {
        self.audioService.seek(by: deltaSeconds)
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
        self.advance(direction: .next, userInitiated: true)
    }

    func playPrevious() {
        if self.audioService.currentTime > Self.restartThreshold {
            self.audioService.seek(to: 0)
            return
        }

        self.advance(direction: .previous, userInitiated: true)
    }

    func setRepeatMode(_ mode: RepeatMode) {
        self.repeatMode = mode
        UserDefaults.standard.set(
            mode.rawValue,
            forKey: Keys.repeatMode
        )
    }

    func toggleShuffle() {
        self.isShuffleEnabled.toggle()
        UserDefaults.standard.set(
            self.isShuffleEnabled,
            forKey: Keys.shuffleEnabled
        )

        if self.isShuffleEnabled {
            self.rebuildShuffleOrder(startingWith: self.track)
        } else {
            self.shuffleOrder = nil
        }
    }

    // MARK: - Properties. Private

    @Injected
    @ObservationIgnored
    private var persistenceService: PersistenceServicing
    private let audioService = AudioService.shared
    private var isLoading: Bool = false
    private var cancellables = Set<AnyCancellable>()
    /// Shuffled track ids for the current queue; `nil` when shuffle is off.
    private var shuffleOrder: [String]?

    private static let restartThreshold: TimeInterval = 3

    private enum Keys {
        static let repeatMode = "UserDefaultsRepeatModeKey"
        static let shuffleEnabled = "UserDefaultsShuffleEnabledKey"
    }

    // MARK: - Methods. Private

    private var playOrder: [TrackEntity] {
        guard let tracks = self.playlist?.tracks, tracks.isNotEmpty else { return [] }

        guard self.isShuffleEnabled, let shuffleOrder else {
            return tracks
        }

        let byId = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return shuffleOrder.compactMap { byId[$0] }
    }

    private func handleTrackFinished() {
        switch self.repeatMode {
            case .one:
                // Stay on the same track — shuffle must not pick another item.
                self.audioService.restartCurrentTrack()

            case .all, .off:
                self.advance(direction: .next, userInitiated: false)
        }
    }

    private func advance(direction: PlaybackDirection, userInitiated: Bool) {
        // Defensive: auto-finish must never skip while repeating one.
        if self.repeatMode == .one, userInitiated == false {
            self.audioService.restartCurrentTrack()
            return
        }

        let tracks = self.playOrder
        guard tracks.isNotEmpty else { return }

        guard let current = self.track,
              let index = tracks.firstIndex(where: { $0.id == current.id }) else {
            self.play(tracks[0])
            return
        }

        let candidate: Int

        switch direction {
            case .next:
                candidate = index + 1

            case .previous:
                candidate = index - 1
        }

        if tracks.indices.contains(candidate) {
            self.play(tracks[candidate])
            return
        }

        switch self.repeatMode {
            case .all:
                let wrapped = direction == .next ? 0 : tracks.count - 1
                self.play(tracks[wrapped])

            case .off:
                if userInitiated {
                    return
                }
                self.resetPlayback()

            case .one:
                self.audioService.restartCurrentTrack()
        }
    }

    private func play(_ track: TrackEntity) {
        self.start(track, using: { trackId, url, _ in
            self.audioService.play(trackId: trackId, url: url, loop: false)
        })
    }

    private func toggle(_ track: TrackEntity) {
        self.start(track, using: { trackId, url, _ in
            self.audioService.toggle(trackId: trackId, url: url, loop: false)
        })
    }

    private func start(
        _ track: TrackEntity,
        using playAction: (_ trackId: String, _ url: URL, _ loop: Bool) -> Void
    ) {
        switch track.source {
            case .api:
                do {
                    let url = try FileManagerService.makeDownloadedTrackURL(id: track.id)
                    self.track = track
                    playAction(track.id, url, false)
                    self.audioService.setNowPlaying(track: track)
                } catch {
                    AppLogger.audio.error("Failed to make track URL: \(String(describing: error))")
                }

            case .imported:
                guard let url = self.resolveImportedURL(for: track) else {
                    AppLogger.audio.error("Imported file missing for track: \(track.id)")
                    return
                }

                self.track = track
                playAction(track.id, url, false)
                self.audioService.setNowPlaying(track: track)
        }
    }

    private func rebuildShuffleOrder(startingWith current: TrackEntity?) {
        guard let tracks = self.playlist?.tracks, tracks.isNotEmpty else {
            self.shuffleOrder = nil
            return
        }

        var ids = tracks.map(\.id).shuffled()

        if let current {
            ids.removeAll { $0 == current.id }
            ids.insert(current.id, at: 0)
        }

        self.shuffleOrder = ids
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
