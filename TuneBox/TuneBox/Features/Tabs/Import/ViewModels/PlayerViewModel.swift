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
    private(set) var scrollToCurrentTrackRequest = 0
    private(set) var sourceFormatText: String = ""
    private(set) var outputRouteText: String = ""
    let vinylRevolutionDuration: TimeInterval = 18
    private(set) var vinylSpinDirection: Double = 1
    private(set) var vinylSpinSpeed: Double = 1
    private(set) var isSeekScrubbing = false
    private(set) var isVinylTapSpinning = false
    private(set) var isShuffleEnabled = false

    var isPlayerVisible: Bool {
        self.settingsVM.hasPremium
        && self.track.isNotNil
    }

    var currentPlaybackTime: TimeInterval {
        if self.isSeekScrubbing {
            return self.playbackTime(for: self.progress)
        }

        if self.progress <= 0 {
            return 0
        }

        if self.isPlaying {
            let currentTime = self.audioService.currentTime
            if currentTime > 0 {
                return currentTime
            }
        }

        return self.playbackTime(for: self.progress)
    }

    var spectrumBands: [Float] {
        self.equalizerService.bands
    }

    var spectrumBandCount: Int {
        self.equalizerService.bandCount
    }

    var spectrumBandCenters: [Float] {
        self.equalizerService.bandCenters
    }

    // MARK: - Initializer

    init() {
        self.audioService.stateChangeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.applyPlayingState(isPlaying)
            }
            .store(in: &self.cancellables)

        self.routePauseObserver = NotificationCenter.default.addObserver(
            forName: .playbackDidPauseForRouteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            VinylSpinGate.block()
            self.isPlaying = false
        }

        self.audioService.progressSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self else { return }
                guard self.isSeekScrubbing.isFalse else { return }
                // After next/previous the engine can briefly report the old
                // position. Don't let that overwrite a reset-to-zero.
                if self.progress <= 0, value > 0, self.isPlaying.isFalse {
                    return
                }

                self.progress = value
                self.stopSeekScrubbingIfNeeded(at: value)
                self.persistPlaybackSessionIfNeeded()
            }
            .store(in: &self.cancellables)

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
        guard self.settingsVM.hasPremium else {
            self.settingsVM.presentPaywall()

            return
        }

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
        self.clearSeekScrubbing()

        if self.playFromPausedTrackEnd() {
            self.persistPlaybackSession()
            return
        }

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
        self.pendingRestoreTrackId = self.pendingRestoreProgress != nil ? track.id : nil
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
            self.play(track, autoplay: false)
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

    func requestScrollToCurrentTrack() {
        self.scrollToCurrentTrackRequest += 1
    }

    func seek(by deltaSeconds: TimeInterval) {
        // Hold-scrub can run after session restore before the engine has duration.
        if self.isSeekScrubbing {
            self.applySeekHoldProgress(deltaSeconds: deltaSeconds)
            return
        }

        self.audioService.seek(by: deltaSeconds)

        let direction = deltaSeconds >= 0 ? 1.0 : -1.0
        self.startVinylTapSpin(direction: direction)
    }

    func seek(to progress: Double) {
        let clamped = min(max(progress, 0), 1)

        if self.isSeekScrubbing {
            let previous = self.lastSeekProgress ?? self.progress
            let delta = clamped - previous
            self.updateVinylScrubSpin(for: delta)
            self.lastSeekProgress = clamped
            self.progress = clamped
            // Slider (and any scrub): finish-per-mode only if released at end while playing.
            self.pendingFinishOnRelease = self.isPlaying && self.isAtTrackEnd
        }

        self.audioService.seek(to: clamped)
        self.persistPlaybackSession()
    }

    func setSeekScrubbing(_ isScrubbing: Bool, direction: Double = 0) {
        self.cancelVinylTapSpin()
        self.cancelVinylScrubIdleFreeze()
        self.resetPendingScrubDirection()

        if isScrubbing {
            if self.isSeekScrubbing.isFalse {
                self.lastSeekProgress = self.progress
                self.pendingFinishOnRelease = false
            }

            if direction == 0 {
                self.vinylSpinSpeed = 0
            } else {
                self.vinylSpinDirection = direction > 0 ? 1 : -1
                self.vinylSpinSpeed = Self.vinylScrubSpinSpeed
            }
        } else {
            let shouldFinishPerMode = self.pendingFinishOnRelease
            self.pendingFinishOnRelease = false
            self.vinylSpinDirection = 1
            self.vinylSpinSpeed = 1
            self.lastSeekProgress = nil

            self.audioService.setSeekScrubbing(false, direction: direction)
            self.isSeekScrubbing = false

            // Playing + released at end (hold or slider) → apply repeat mode.
            // Defer so SwiftUI Slider can leave the drag gesture before progress jumps.
            guard shouldFinishPerMode else { return }
            Task { @MainActor in
                await Task.yield()
                self.handleTrackFinished()
            }
            return
        }

        self.audioService.setSeekScrubbing(isScrubbing, direction: direction)
        self.isSeekScrubbing = isScrubbing
    }

    func resetPlayback() {
        self.clearSeekScrubbing()
        self.audioService.stop()
        self.track = nil
        self.progress = 0
        self.isPlaying = false
        self.isVinylTapSpinning = false
        self.vinylSpinDirection = 1
        self.vinylSpinSpeed = 1
        self.vinylTapSpinTask?.cancel()
        self.vinylTapSpinTask = nil
        self.vinylScrubIdleTask?.cancel()
        self.vinylScrubIdleTask = nil
        self.playbackNavigationPath = []
        self.playbackOrigin = nil
        self.pendingRestoreProgress = nil
        self.pendingRestoreTrackId = nil
        self.needsNavigationPathRebuild = false
        self.clearPersistedPlaybackSession()
    }

    func stopAudioPreservingSession() {
        self.persistPlaybackSession()
        self.clearSeekScrubbing()
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

    func appendDownloadedTracks(_ tracks: [TrackEntity]) {
        guard case .downloads = self.playbackOrigin else { return }
        guard let currentTracks = self.playlist?.tracks, currentTracks.isNotEmpty else { return }

        let existing = Set(currentTracks.map(\.id))
        let added = tracks.filter { existing.contains($0.id) == false }
        guard added.isNotEmpty else { return }

        self.playlist = PlaylistEntity(title: "Queue", tracks: currentTracks + added)

        if self.isShuffleEnabled, var order = self.shuffleOrder {
            order.append(contentsOf: added.map(\.id))
            self.shuffleOrder = order
        }

        self.persistPlaybackSession()
    }

    func isPlaying(_ track: TrackEntity) -> Bool {
        self.track?.id == track.id && self.isPlaying
    }

    func playNext() {
        if self.repeatMode == .one {
            self.restartCurrentTrackPlayback()
            return
        }

        self.advance(direction: .next, autoplay: self.isPlaying)
    }

    func playPrevious() {
        if self.repeatMode == .one {
            self.restartCurrentTrackPlayback()
            return
        }

        self.ensureShuffleOrderIfNeeded()

        if self.playbackElapsedTime > Self.restartThreshold {
            self.restartCurrentTrackPlayback()
            return
        }

        if self.repeatMode == .off, self.isAtFirstTrack {
            self.returnToTrackStartAndPause()
            return
        }

        self.advance(direction: .previous, autoplay: self.isPlaying)
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
    @ObservationIgnored
    @Injected
    private var settingsVM: SettingsManaging
    @Injected
    @ObservationIgnored
    private var audioService: AudioServicing
    @Injected
    @ObservationIgnored
    private var equalizerService: EqualizerServicing
    @Injected
    @ObservationIgnored
    private var analytics: AnalyticsServicing
    @Injected
    @ObservationIgnored
    private var crashlytics: CrashlyticsServicing
    private var isLoading: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private var routePauseObserver: NSObjectProtocol?
    private var shuffleOrder: [String]?
    private var playbackOrigin: PlaybackOriginSnapshot?
    private var pendingRestoreProgress: Double?
    private var pendingRestoreTrackId: String?
    private var lastPersistedProgressAt: Date?
    private var needsNavigationPathRebuild = false
    private var vinylTapSpinTask: Task<Void, Never>?
    private var vinylScrubIdleTask: Task<Void, Never>?
    @ObservationIgnored
    private var lastSeekProgress: Double?
    @ObservationIgnored
    private var pendingScrubDirection: Double?
    @ObservationIgnored
    private var pendingScrubDirectionCount = 0
    @ObservationIgnored
    private var pendingFinishOnRelease = false

    private static let trackEndSlop: TimeInterval = 0.05
    private static let restartThreshold: TimeInterval = 5
    private static let persistProgressInterval: TimeInterval = 5
    private static let vinylScrubSpinSpeed: Double = 2.5
    private static let vinylScrubDirectionThreshold: Double = 0.0001
    private static let vinylScrubIdleFreezeNanoseconds: UInt64 = 150_000_000
    private static let vinylTapSpinSpeed: Double = 3.0
    private static let vinylTapSpinDurationNanoseconds: UInt64 = 400_000_000

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

    private var isAtFirstTrack: Bool {
        self.isAtQueueEdge(offset: 0)
    }

    private var isAtLastTrack: Bool {
        let tracks = self.playOrder
        guard tracks.isNotEmpty else { return true }
        return self.isAtQueueEdge(offset: tracks.count - 1)
    }

    private func isAtQueueEdge(offset: Int) -> Bool {
        let tracks = self.playOrder
        guard
            let current = self.track,
            let index = tracks.firstIndex(where: { $0.id == current.id })
        else {
            return true
        }

        return index == offset
    }

    private var playbackElapsedTime: TimeInterval {
        if self.progress <= 0 {
            return 0
        }

        let currentTime = self.audioService.currentTime

        if currentTime > 0 {
            return currentTime
        }

        guard let duration = self.track?.duration, duration > 0 else {
            return 0
        }

        return Double(duration) * self.progress
    }

    private func resetPlaybackPosition() {
        self.clearSeekScrubbing()
        self.pendingRestoreProgress = nil
        self.pendingRestoreTrackId = nil
        self.progress = 0
        self.audioService.seek(to: 0)
        self.persistPlaybackSession()
    }

    private func restartCurrentTrackPlayback() {
        self.clearSeekScrubbing()
        self.pendingRestoreProgress = nil
        self.pendingRestoreTrackId = nil
        self.progress = 0

        if self.isPlaying {
            self.restartCurrentTrackFromBeginning(autoplay: true)
        } else {
            self.audioService.seek(to: 0)
            self.equalizerService.reset()
        }

        self.persistPlaybackSession()
    }

    /// Restarts the current track for repeat-one / play-from-end.
    /// After a cold session restore the engine has no file yet — fall back to `play`.
    private func restartCurrentTrackFromBeginning(autoplay: Bool) {
        guard let track = self.track else { return }

        self.pendingRestoreProgress = nil
        self.pendingRestoreTrackId = nil
        self.progress = 0

        if self.audioService.restartCurrentTrack() {
            return
        }

        self.play(track, autoplay: autoplay)
    }

    private func startVinylTapSpin(direction: Double) {
        self.cancelVinylTapSpin()

        self.vinylSpinDirection = direction
        self.vinylSpinSpeed = Self.vinylTapSpinSpeed
        self.isVinylTapSpinning = true

        self.vinylTapSpinTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.vinylTapSpinDurationNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            guard self.isSeekScrubbing.isFalse else {
                return
            }

            self.isVinylTapSpinning = false
            self.vinylSpinDirection = 1
            self.vinylSpinSpeed = 1
            self.vinylTapSpinTask = nil
        }
    }

    private func cancelVinylTapSpin() {
        self.vinylTapSpinTask?.cancel()
        self.vinylTapSpinTask = nil
        self.isVinylTapSpinning = false
    }

    private func updateVinylScrubSpin(for delta: Double) {
        guard abs(delta) > Self.vinylScrubDirectionThreshold else {
            return
        }

        let newDirection = delta > 0 ? 1.0 : -1.0
        let isSpinning = self.vinylSpinSpeed != 0

        if isSpinning, newDirection == self.vinylSpinDirection {
            self.resetPendingScrubDirection()
            self.scheduleVinylScrubIdleFreeze()
            return
        }

        if self.pendingScrubDirection == newDirection {
            self.pendingScrubDirectionCount += 1
        } else {
            self.pendingScrubDirection = newDirection
            self.pendingScrubDirectionCount = 1
        }

        guard self.pendingScrubDirectionCount >= 2 else {
            return
        }

        self.vinylSpinDirection = newDirection
        self.vinylSpinSpeed = Self.vinylScrubSpinSpeed
        self.resetPendingScrubDirection()
        self.scheduleVinylScrubIdleFreeze()
    }

    private func resetPendingScrubDirection() {
        self.pendingScrubDirection = nil
        self.pendingScrubDirectionCount = 0
    }

    private func scheduleVinylScrubIdleFreeze() {
        self.cancelVinylScrubIdleFreeze()

        self.vinylScrubIdleTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.vinylScrubIdleFreezeNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            guard self.isSeekScrubbing else {
                return
            }

            self.vinylSpinSpeed = 0
            self.vinylScrubIdleTask = nil
        }
    }

    private func cancelVinylScrubIdleFreeze() {
        self.vinylScrubIdleTask?.cancel()
        self.vinylScrubIdleTask = nil
    }

    private func applyAudioProgress() {
        let duration = self.effectiveDuration
        guard duration > 0 else { return }

        let currentTime = self.audioService.duration > 0
            ? self.audioService.currentTime
            : duration * self.progress
        self.progress = min(max(currentTime / duration, 0), 1)
    }

    private func applySeekHoldProgress(deltaSeconds: TimeInterval) {
        let duration = self.effectiveDuration
        guard duration > 0 else { return }

        let newProgress = min(max(self.progress + (deltaSeconds / duration), 0), 1)
        self.progress = newProgress
        self.lastSeekProgress = newProgress
        // Sync scrub cursor even when the engine has not opened the file yet.
        self.audioService.seek(to: newProgress)
        self.stopSeekScrubbingIfNeeded(at: newProgress)
    }

    private var effectiveDuration: TimeInterval {
        let engineDuration = self.audioService.duration
        if engineDuration > 0 {
            return engineDuration
        }

        guard let trackDuration = self.track?.duration, trackDuration > 0 else {
            return 0
        }

        return TimeInterval(trackDuration)
    }

    private func playbackTime(for progress: Double) -> TimeInterval {
        self.effectiveDuration * progress
    }

    private func clearSeekScrubbing() {
        guard self.isSeekScrubbing else { return }
        // Aborting scrub (play/pause, reset, etc.) must not advance the queue.
        self.pendingFinishOnRelease = false
        self.setSeekScrubbing(false)
    }

    private func stopSeekScrubbingIfNeeded(at progress: Double) {
        guard self.isSeekScrubbing else { return }

        let reachedStart = self.vinylSpinDirection < 0 && progress <= 0
        let reachedEnd = self.vinylSpinDirection > 0 && progress >= 1
        guard reachedStart || reachedEnd else { return }

        if reachedEnd {
            self.progress = 1
            // Defer mode handling until release. Paused never advances.
            self.pendingFinishOnRelease = self.isPlaying
        } else {
            self.progress = 0
            self.pendingFinishOnRelease = false
        }

        self.cancelVinylTapSpin()
        self.vinylSpinSpeed = 0
    }

    private func playFromPausedTrackEnd() -> Bool {
        guard self.isPlaying.isFalse, self.isAtTrackEnd else { return false }

        // No Repeat on the last track means the queue is already finished.
        guard self.repeatMode != .off || self.isAtLastTrack.isFalse else { return true }

        if self.repeatMode == .one {
            // Must actually start playback (engine may be empty after cold restore).
            self.restartCurrentTrackFromBeginning(autoplay: true)
            return true
        }

        self.handleTrackFinished()
        return true
    }

    private var isAtTrackEnd: Bool {
        let duration = self.audioService.duration
        guard duration > 0 else { return self.progress >= 1 }

        let remaining = duration * (1 - min(max(self.progress, 0), 1))
        return remaining <= Self.trackEndSlop
    }

    private func handleTrackFinished() {
        switch self.repeatMode {
            case .one:
                self.restartCurrentTrackFromBeginning(autoplay: true)

            case .all:
                self.advance(direction: .next)

            case .off:
                if self.isAtLastTrack {
                    self.returnToTrackStartAndPause()
                } else {
                    self.advance(direction: .next)
                }
        }
    }

    private func advance(direction: PlaybackDirection, autoplay: Bool = true) {
        self.ensureShuffleOrderIfNeeded()

        let tracks = self.playOrder
        guard tracks.isNotEmpty else { return }

        guard let current = self.track,
              let index = tracks.firstIndex(where: { $0.id == current.id }) else {
            self.play(tracks[0], autoplay: autoplay)
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
            self.progress = 0
            self.play(tracks[candidate], autoplay: autoplay)
            return
        }

        guard self.repeatMode == .all else { return }

        let wrapped = direction == .next ? 0 : tracks.count - 1
        self.progress = 0
        self.play(tracks[wrapped], autoplay: autoplay)
    }

    private func returnToTrackStartAndPause() {
        self.resetPlaybackPosition()
        self.audioService.seekToStartAndPause()
        self.isPlaying = false
    }

    private func applyPlayingState(_ playing: Bool) {
        if playing {
            VinylSpinGate.allow()
        } else {
            VinylSpinGate.block()
        }

        self.isPlaying = playing
    }

    private func play(_ track: TrackEntity, autoplay: Bool = true) {
        if autoplay {
            VinylSpinGate.allow()
        } else {
            self.equalizerService.reset()
        }

        if self.track?.id != track.id, self.pendingRestoreProgress == nil {
            self.progress = 0
        }

        self.start(track, using: { trackId, url, _ in
            self.audioService.play(trackId: trackId, url: url, loop: false, autoplay: autoplay)
        }, reportPlayStart: autoplay)
    }

    private func toggle(_ track: TrackEntity) {
        if self.isPlaying.isFalse {
            VinylSpinGate.allow()
        }

        self.start(track, using: { trackId, url, _ in
            self.audioService.toggle(trackId: trackId, url: url, loop: false)
        })
    }

    private func start(
        _ track: TrackEntity,
        using playAction: (_ trackId: String, _ url: URL, _ loop: Bool) -> Void,
        reportPlayStart: Bool = false
    ) {
        guard self.settingsVM.hasPremium else {
            return
        }

        switch track.source {
            case .api:
                do {
                    let url = try FileManagerService.makeDownloadedTrackURL(id: track.id)
                    self.track = track
                    playAction(track.id, url, false)
                    self.audioService.setNowPlaying(track: track)
                    CoverImageLoader.applyNowPlayingArtwork(from: track.imagePath)
                    self.applyPendingRestoreSeekIfNeeded()
                    self.persistPlaybackSession()
                    self.logPlayStartIfNeeded(reportPlayStart, track: track, url: url)
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
                CoverImageLoader.applyNowPlayingArtwork(from: track.imagePath)
                self.applyPendingRestoreSeekIfNeeded()
                self.persistPlaybackSession()
                self.logPlayStartIfNeeded(reportPlayStart, track: track, url: url)
        }
    }

    private func logPlayStartIfNeeded(_ shouldLog: Bool, track: TrackEntity, url: URL) {
        guard shouldLog else { return }

        self.analytics.log(
            .playStart(
                source: track.source.rawValue,
                format: Self.analyticsFormat(for: url)
            )
        )
    }

    private static func analyticsFormat(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()

        switch ext {
            case "dsf", "dff":
                return "dsd"

            case "":
                return "unknown"

            default:
                return ext
        }
    }

    private func applyPendingRestoreSeekIfNeeded() {
        guard self.pendingRestoreProgress != nil else { return }
        let restoreTrackId = self.pendingRestoreTrackId
        self.pendingRestoreProgress = nil
        self.pendingRestoreTrackId = nil

        // Prefer current UI progress — user may have hold/scrubbed after restore.
        let target = self.progress
        guard target > 0, target < 1 else { return }

        // Let SFB finish opening the decoder before seeking.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Don't apply a session restore seek to a different track the user
            // already switched to while this callback was pending.
            guard restoreTrackId == nil || self.track?.id == restoreTrackId else { return }
            // User already skipped/rewound to the start.
            guard self.progress > 0 else { return }
            self.audioService.seek(to: self.progress)
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
                    return [.artists, .artist(artist, segment: .tracks)]
                }
                guard let artist = Self.makeArtist(id: id, persistence: persistence) else { return [] }
                return [.artists, .artist(artist, segment: .tracks)]

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
        let tracks = AlbumTrackOrdering.ordered(
            ((try? persistence.getImportTracks()) ?? [])
                .filter { $0.albumName == id }
        )
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

    private func ensureShuffleOrderIfNeeded() {
        guard self.isShuffleEnabled else { return }
        guard self.shuffleOrder == nil else { return }
        self.rebuildShuffleOrder(startingWith: self.track)
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.error = message
        AppLogger.imported.warning("\(message)")
        self.crashlytics.record(error, area: .player)
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
