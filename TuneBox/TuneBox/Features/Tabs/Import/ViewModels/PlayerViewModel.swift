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
    private(set) var isPlaying = false
    private(set) var error: String?
    private(set) var playbackNavigationPath: [AppRoute] = []
    private(set) var sourceFormatText: String = ""
    private(set) var outputRouteText: String = ""
    let vinylRevolutionDuration: TimeInterval = 8
    private(set) var isShuffleEnabled = false

    var isPlayerVisible: Bool {
        self.track != nil
    }

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
                guard let self else { return }
                self.progress = value
                self.persistPlaybackSessionIfNeeded()
            }
            .store(in: &cancellables)

        self.audioService.formatInfoSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.sourceFormatText = info.source
                self?.outputRouteText = info.output
            }
            .store(in: &self.cancellables)

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

        self.sourceFormatText = self.audioService.sourceFormatText
        self.outputRouteText = self.audioService.outputRouteText
    }

    // MARK: - Methods. Public

    func loadPlaylist() {
        self.isLoading = true

        defer {
            self.isLoading = false
        }

        if let playlistID = UserDefaults.standard.string(forKey: GlobalConstants.UserDefaultsKey.playlistID) {
            do {
                if let playlist = try self.persistenceService.getPlaylist(id: playlistID) {
                    self.playlist = playlist
                }
            } catch {
                self.handleError(error)
            }
        }
    }

    func handlePlayAction(for track: TrackEntity, in queue: [TrackEntity], navigationPath: [AppRoute]? = nil) {
        if let navigationPath {
            self.playbackNavigationPath = navigationPath
            self.playbackOrigin = self.makeOrigin(from: navigationPath)
            self.needsNavigationPathRebuild = false
        }

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

        self.persistPlaybackSession()
    }

    func togglePlayPause() {
        guard let track = self.track else { return }
        self.toggle(track)
        self.persistPlaybackSession()
    }

    func restoreLastPlaybackSession() {
        guard self.track == nil else { return }

        guard
            let data = UserDefaults.standard.data(forKey: Keys.playbackSession),
            let snapshot = try? JSONDecoder().decode(PlaybackSessionSnapshot.self, from: data)
        else {
            return
        }

        guard let track = try? self.persistenceService.getTrack(id: snapshot.trackID) else {
            // Track removed from library — drop stale session.
            self.clearPersistedPlaybackSession()
            return
        }

        // Still restore UI even if the file is temporarily unresolved; play will validate.
        let queue = snapshot.queueTrackIDs.compactMap { id in
            try? self.persistenceService.getTrack(id: id)
        }

        let tracks: [TrackEntity]
        if queue.contains(where: { $0.id == track.id }) {
            tracks = queue
        } else {
            tracks = [track]
        }

        self.track = track
        self.playlist = PlaylistEntity(title: "Queue", tracks: tracks)
        self.progress = min(max(snapshot.progress, 0), 1)
        self.isPlaying = false
        self.playbackOrigin = snapshot.origin
        self.pendingRestoreProgress = self.isPlayableOnDisk(track) ? self.progress : nil
        self.needsNavigationPathRebuild = true
        self.playbackNavigationPath = Self.rebuildPath(
            from: snapshot.origin,
            library: nil,
            persistence: self.persistenceService
        )
        if self.playbackNavigationPath.isNotEmpty {
            self.needsNavigationPathRebuild = false
        }

        if self.isShuffleEnabled {
            self.rebuildShuffleOrder(startingWith: track)
        }

        self.refreshFormatInfo(for: track)

        if self.pendingRestoreProgress != nil {
            self.audioService.setSeekScrubbing(true)
            self.play(track)
            self.audioService.pause()
            self.audioService.setSeekScrubbing(false)
        }
    }

    func persistPlaybackSession() {
        guard let track = self.track else {
            self.clearPersistedPlaybackSession()
            return
        }

        let snapshot = PlaybackSessionSnapshot(
            trackID: track.id,
            progress: self.progress,
            queueTrackIDs: self.playlist?.tracks.map(\.id) ?? [track.id],
            origin: self.playbackOrigin
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Keys.playbackSession)
        self.lastPersistedProgressAt = Date()
    }

    func refreshPlaybackNavigationPath(library: MusicLibrary?) {
        guard self.needsNavigationPathRebuild || self.playbackNavigationPath.isEmpty else { return }
        guard self.playbackOrigin != nil else { return }

        let path = Self.rebuildPath(
            from: self.playbackOrigin,
            library: library,
            persistence: self.persistenceService
        )
        guard path.isNotEmpty else { return }

        self.playbackNavigationPath = path
        self.needsNavigationPathRebuild = false
    }

    func seek(by deltaSeconds: TimeInterval) {
        self.audioService.seek(by: deltaSeconds)
    }

    func setSeekScrubbing(_ isScrubbing: Bool) {
        self.audioService.setSeekScrubbing(isScrubbing)
    }

    func resetPlayback() {
        self.audioService.stop()
        self.track = nil
        self.progress = 0
        self.isPlaying = false
        self.playbackNavigationPath = []
        self.playbackOrigin = nil
        self.pendingRestoreProgress = nil
        self.needsNavigationPathRebuild = false
        self.clearPersistedPlaybackSession()
    }

    func stopAudioPreservingSession() {
        self.persistPlaybackSession()
        self.audioService.stop()
        self.isPlaying = false
    }

    func clearPlaybackIfAffected(byRemovedSourceID sourceID: UUID, isAPISource: Bool) {
        if isAPISource {
            let playsDownloaded = self.track?.source == .api
            let fromDownloadsOrigin: Bool = {
                if case .downloads = self.playbackOrigin { return true }
                return false
            }()

            if playsDownloaded || fromDownloadsOrigin {
                self.resetPlayback()
            }
            return
        }

        let sourceKey = sourceID.uuidString
        let currentFromSource = self.track?.importSourceID == sourceKey
        let queueFromSource = self.playlist?.tracks.contains { $0.importSourceID == sourceKey } == true
        let originFromSource: Bool = {
            if case .sourceFolder(let id, _) = self.playbackOrigin {
                return id == sourceID
            }
            return false
        }()

        if currentFromSource || originFromSource || queueFromSource {
            self.resetPlayback()
        }
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
    private var shuffleOrder: [String]?
    private var playbackOrigin: PlaybackOriginSnapshot?
    private var pendingRestoreProgress: Double?
    private var lastPersistedProgressAt: Date?
    private var needsNavigationPathRebuild = false

    private static let restartThreshold: TimeInterval = 3
    private static let persistProgressInterval: TimeInterval = 5

    private enum Keys {
        static let playbackSession = "UserDefaultsPlaybackSessionKey"
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
                self.audioService.restartCurrentTrack()

            case .all, .off:
                self.advance(direction: .next, userInitiated: false)
        }
    }

    private func advance(direction: PlaybackDirection, userInitiated: Bool) {
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
                self.stopAudioPreservingSession()
                self.progress = 0

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
                    self.applyPendingRestoreSeekIfNeeded()
                    self.persistPlaybackSession()
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
                self.applyPendingRestoreSeekIfNeeded()
                self.persistPlaybackSession()
        }
    }

    private func applyPendingRestoreSeekIfNeeded() {
        guard let pending = self.pendingRestoreProgress else { return }
        self.pendingRestoreProgress = nil
        guard pending > 0, pending < 1 else { return }

        // Let SFB finish opening the decoder before seeking.
        DispatchQueue.main.async { [weak self] in
            self?.audioService.seek(to: pending)
        }
    }

    private func refreshFormatInfo(for track: TrackEntity) {
        let url: URL?
        switch track.source {
            case .imported:
                url = self.resolveImportedURL(for: track)

            case .api:
                url = try? FileManagerService.makeDownloadedTrackURL(id: track.id)
        }

        guard let url else { return }
        self.audioService.refreshFormatInfo(for: url)
    }

    private func persistPlaybackSessionIfNeeded() {
        guard self.track != nil, self.isPlaying else { return }

        let now = Date()
        if let last = self.lastPersistedProgressAt,
           now.timeIntervalSince(last) < Self.persistProgressInterval {
            return
        }

        self.persistPlaybackSession()
    }

    private func clearPersistedPlaybackSession() {
        UserDefaults.standard.removeObject(forKey: Keys.playbackSession)
        self.lastPersistedProgressAt = nil
    }

    private func makeOrigin(from path: [AppRoute]) -> PlaybackOriginSnapshot? {
        guard var origin = PlaybackOriginSnapshot(from: path) else { return nil }

        if case .playlist(_, let title) = origin,
           let playlists = try? self.persistenceService.fetchPlaylists(),
           let match = playlists.first(where: { $0.title == title }) {
            origin = .playlist(id: match.id, title: title)
        }

        return origin
    }

    private func isPlayableOnDisk(_ track: TrackEntity) -> Bool {
        switch track.source {
            case .imported:
                return self.resolveImportedURL(for: track) != nil

            case .api:
                guard let url = try? FileManagerService.makeDownloadedTrackURL(id: track.id) else {
                    return false
                }
                return FileManager.default.fileExists(atPath: url.path)
        }
    }

    private static func rebuildPath(
        from origin: PlaybackOriginSnapshot?,
        library: MusicLibrary?,
        persistence: PersistenceServicing
    ) -> [AppRoute] {
        guard let origin else { return [] }

        switch origin {
            case .sourceFolder(let id, let path):
                return [.sourceFolder(sourceID: id, path: path)]

            case .album(let id):
                if let album = library?.albums.first(where: { $0.id == id }) {
                    return [.albums, .album(album)]
                }
                guard let album = Self.makeAlbum(id: id, persistence: persistence) else { return [] }
                return [.albums, .album(album)]

            case .artist(let id):
                if let artist = library?.artists.first(where: { $0.id == id }) {
                    return [.artists, .artist(artist)]
                }
                guard let artist = Self.makeArtist(id: id, persistence: persistence) else { return [] }
                return [.artists, .artist(artist)]

            case .playlist(let id, let title):
                let playlist =
                    (try? persistence.getPlaylist(id: id))
                    ?? (try? persistence.fetchPlaylists().first(where: { $0.title == title }))
                guard let playlist else { return [] }
                return [.playlists, .tracks(title, .fixed(playlist.tracks))]

            case .tracksLibrary(let title):
                return [.tracks(title, .library)]

            case .downloads:
                return [.tracks(nil, .downloads)]
        }
    }

    private static func makeAlbum(
        id: String,
        persistence: PersistenceServicing
    ) -> MusicLibrary.Album? {
        // Album.id is the album name in parseLibrary.
        let tracks = ((try? persistence.getImportTracks()) ?? [])
            .filter { $0.albumName == id }
            .sorted { lhs, rhs in
                let left = (lhs.trackNumber ?? Int.max, lhs.songName.localizedLowercase)
                let right = (rhs.trackNumber ?? Int.max, rhs.songName.localizedLowercase)
                return left < right
            }
        guard tracks.isNotEmpty else { return nil }

        return MusicLibrary.Album(
            id: id,
            name: id,
            artist: tracks.first?.artistName ?? "",
            date: tracks.compactMap(\.releaseDate).first { !$0.isEmpty },
            tracks: tracks,
            cover: tracks.first?.imagePath
        )
    }

    private static func makeArtist(
        id: String,
        persistence: PersistenceServicing
    ) -> MusicLibrary.Artist? {
        // Artist.id is the artist name in parseLibrary.
        let tracks = ((try? persistence.getImportTracks()) ?? [])
            .filter { $0.artistName == id }
        guard tracks.isNotEmpty else { return nil }

        return MusicLibrary.Artist(
            id: id,
            name: id,
            tracks: tracks,
            albums: []
        )
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
        let preferredExt = track.localFileURL?.pathExtension ?? ""
        let candidates: [String]
        if preferredExt.isEmpty {
            candidates = [
                AudioFileExtension.flac.rawValue,
                AudioFileExtension.mp3.rawValue,
                AudioFileExtension.wav.rawValue,
                AudioFileExtension.m4a.rawValue,
                AudioFileExtension.aiff.rawValue,
                AudioFileExtension.aif.rawValue,
                AudioFileExtension.dsf.rawValue,
                AudioFileExtension.dff.rawValue,
                AudioFileExtension.wv.rawValue,
                AudioFileExtension.ogg.rawValue,
                AudioFileExtension.opus.rawValue
            ]
        } else {
            candidates = [preferredExt]
        }

        for ext in candidates {
            guard let url = try? FileManagerService.makeImportedTrackURL(
                id: track.id,
                fileExtension: ext
            ), FileManager.default.fileExists(atPath: url.path) else {
                continue
            }
            return url
        }

        // Fallback: stored absolute path from import time.
        if let stored = track.localFileURL,
           FileManager.default.fileExists(atPath: stored.path) {
            return stored
        }

        return nil
    }
}
