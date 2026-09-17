//
//  AudioService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 30.07.2026.
//

import Foundation
import Combine
import AVFoundation
import SFBAudioEngine
import MediaPlayer

final class AudioService: NSObject, AudioServicing {

    // MARK: - Properties. Public

    private(set) var currentTrackId: String?
    private(set) var sourceFormatText: String = ""
    private(set) var outputRouteText: String = ""
    private(set) var stateChangeSubject = CurrentValueSubject<Bool, Never>(false)
    private(set) var progressSubject = PassthroughSubject<Double, Never>()
    private(set) var formatInfoSubject = CurrentValueSubject<(source: String, output: String), Never>(("", ""))
    var onRemotePlayNext: (() -> Void)?
    var onRemotePlayPrevious: (() -> Void)?
    var onTrackFinished: (() -> Void)?

    var duration: TimeInterval {
        self.player.totalTime ?? 0
    }

    var currentTime: TimeInterval {
        self.player.currentTime ?? 0
    }

    var volume: Float {
        get { self.storedVolume }
        set {
            self.storedVolume = self.clampVolume(newValue)
            guard !self.isDoPPlayback else { return }
            self.applyVolume()
        }
    }

    // MARK: - Methods. Public

    func play(trackId: String, url: URL, loop: Bool = false) {
        AppLogger.audio.info("AudioService PLAY: \(trackId)")

        let isNewTrack = self.currentTrackId != trackId
        if isNewTrack {
            self.savedProgress = 0
            self.cancelPendingProgressRestore()
            self.cancelRestore()
        }

        self.isPausedDueToRouteChange = false
        self.ignoreAutomaticResumeUntil = .distantPast
        self.allowEnginePlaybackRestore()

        self.silenceOutput()
        self.detachEqualizerTap(resetSpectrum: isNewTrack)
        self.stopProgressTimer()
        self.currentTrackId = trackId
        self.currentURL = url
        self.shouldLoop = loop
        self.silenceOutput()
        self.activateAudioSession()

        do {
            let ext = url.pathExtension.lowercased()
            let isDSD = ext == AudioFileExtension.dsf.rawValue
            || ext == AudioFileExtension.dff.rawValue

            if isDSD {
                try self.playDSD(url: url)
            } else {
                try self.startPCMFile(url)
                self.isDoPPlayback = false
            }

            self.silenceOutput()
            self.attachSpectrumIfNeeded()
            self.unfreezeSpectrumAfterRestore()
            self.isPausedDueToRouteChange = false
            self.ignoreAutomaticResumeUntil = .distantPast
            self.notifyStateChange(true)
            self.startProgressTimer()
            self.refreshFormatInfo(for: url)
            self.refreshNowPlayingElapsed()
            self.scheduleUnmute()
        } catch {
            AppLogger.audio.error("Failed to play audio: \(error.localizedDescription)")
            self.notifyStateChange(false)
            self.isDoPPlayback = false
        }
    }

    func pause() {
        self.pause(captureProgress: true)
    }

    func pause(captureProgress: Bool) {
        self.endSeekScrubbingIfNeeded()
        self.forbidEnginePlaybackRestore()

        if captureProgress {
            self.captureProgress()
        }

        self.silenceOutput()
        _ = self.player.pause()
        self.equalizerService.setPlaybackActive(false)
        self.stopProgressTimer()
        self.notifyStateChange(false)
        self.refreshNowPlayingElapsed()
    }

    func resume() {
        self.isPausedDueToRouteChange = false
        self.ignoreAutomaticResumeUntil = .distantPast
        self.allowEnginePlaybackRestore()
        self.endSeekScrubbingIfNeeded()
        self.activateAudioSession()
        self.silenceOutput()

        if self.player.isPlaying {
            self.restoreProgressIfNeeded()
            self.scheduleUnmute()
            return
        }

        if self.needsEngineRebuild.isFalse, self.player.resume() {
            self.attachSpectrumIfNeeded()
            self.unfreezeSpectrumAfterRestore()
            self.startProgressTimer()
            self.isPausedDueToRouteChange = false
            self.notifyStateChange(true)
            self.refreshNowPlayingElapsed()
            self.restoreProgressIfNeeded()
            self.scheduleUnmute()
            return
        }

        _ = self.restoreCurrentTrack()
    }

    func stop() {
        self.detachEqualizerTap()
        self.player.stop()
        self.stopProgressTimer()
        self.currentTrackId = nil
        self.currentURL = nil
        self.isDoPPlayback = false
        self.shouldLoop = false
        self.isSeekScrubbing = false
        self.wasPlayingBeforeScrub = false
        self.wasPlayingBeforeInterruption = false
        self.isPausedDueToRouteChange = false
        self.ignoreAutomaticResumeUntil = .distantPast
        self.forbidEnginePlaybackRestore()
        self.needsEngineRebuild = false
        self.savedProgress = 0
        self.cancelPendingProgressRestore()
        self.cancelRestore()
        self.notifyStateChange(false)
        self.notifyProgress(0)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func restartCurrentTrack() {
        guard let url = self.currentURL, let trackId = self.currentTrackId else { return }

        self.silenceOutput()

        if self.player.seek(position: 0) {
            self.notifyProgress(0)
            self.scheduleUnmute()

            if self.player.isPlaying {
                self.refreshNowPlayingElapsed()
                return
            }

            if self.player.resume() {
                self.notifyStateChange(true)
                self.startProgressTimer()
                self.refreshNowPlayingElapsed()
                return
            }
        }

        self.savedProgress = 0
        self.play(trackId: trackId, url: url, loop: self.shouldLoop)
    }

    func toggle(trackId: String, url: URL, loop: Bool = false) {
        AppLogger.audio.info("AudioService TOGGLE: \(trackId), current: \(self.currentTrackId ?? "nil")")

        if self.currentTrackId != trackId {
            self.play(trackId: trackId, url: url, loop: loop)
            return
        }

        if self.player.isPlaying {
            self.pause()
            return
        }

        // After a headphone/route teardown the engine reports stopped, but this is
        // still the same track — resume from the saved position instead of restarting.
        if self.player.isStopped.isFalse, self.isNearEnd {
            self.stop()
            return
        }

        self.resume()
    }

    func seek(by deltaSeconds: TimeInterval) {
        guard self.duration > 0 else { return }

        if self.isSeekScrubbing.isFalse {
            self.equalizerService.holdUpdatesTemporarily(for: self.spectrumHoldDuration)
        }

        if deltaSeconds >= 0 {
            _ = self.player.seek(forward: deltaSeconds)
        } else {
            _ = player.seek(backward: abs(deltaSeconds))
        }

        self.notifyProgress(self.clampedProgressValue(for: deltaSeconds))
        self.refreshNowPlayingElapsed()
    }

    func setSeekScrubbing(_ isScrubbing: Bool) {
        guard self.isSeekScrubbing != isScrubbing else { return }

        if isScrubbing {
            self.silenceOutput()
            self.wasPlayingBeforeScrub = self.player.isPlaying
            self.isSeekScrubbing = true
            self.equalizerService.holdUpdates()
            return
        }

        self.endSeekScrubbingIfNeeded()
    }

    func refreshFormatInfo(for url: URL) {
        self.updateSourceFormat(for: url)
        self.updateOutputRoute()
    }

    func seek(to progress: Double) {
        guard self.duration > 0 else { return }

        if self.isSeekScrubbing {
            self.equalizerService.holdUpdates()
        } else {
            self.equalizerService.holdUpdatesTemporarily(for: self.spectrumHoldDuration)
        }

        let clamped = min(max(progress, 0), 1)
        _ = self.player.seek(position: clamped)
        self.notifyProgress(clamped)
        self.refreshNowPlayingElapsed()
    }

    func seekToStartAndPause() {
        if self.player.seek(position: 0) {
            self.pause()
            self.notifyProgress(0)
            return
        }

        guard let url = self.currentURL, let trackId = self.currentTrackId else {
            self.pause()
            self.notifyProgress(0)
            return
        }

        self.play(trackId: trackId, url: url, loop: self.shouldLoop)
        _ = self.player.seek(position: 0)
        self.pause()
        self.notifyProgress(0)
    }

    func playEffect(name: String, ext: AudioFileExtension = .mp3) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext.rawValue) else {
            AppLogger.audio.error("Effect file not found: \(name).\(ext.rawValue)")
            return
        }

        do {
            try self.effectPlayer.play(url)
        } catch {
            AppLogger.audio.error("Failed to play effect: \(error.localizedDescription)")
        }
    }

    func setNowPlaying(track: TrackEntity) {
        let playbackDuration: TimeInterval = {
            if self.duration > 0 {
                return self.duration
            }

            if let trackDuration = track.duration, trackDuration > 0 {
                return TimeInterval(trackDuration)
            }

            return 0
        }()

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.songName,
            MPMediaItemPropertyArtist: track.artistName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0
        ]

        if playbackDuration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = playbackDuration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Initializer

    init(equalizerService: EqualizerServicing) {
        self.equalizerService = equalizerService
        super.init()

        self.setupObservers()
        self.player.delegate = self
        self.player.restoresPlaybackAfterEngineReset = false
        self.configureAudioSession()
        self.configureRemoteCommands()
        self.checkHeadphonesConnection(
            outputs: AVAudioSession.sharedInstance().currentRoute.outputs
        )
    }

    // MARK: - Properties. Private

    private let player = AudioPlayer()
    private let effectPlayer = AudioPlayer()
    private let equalizerService: EqualizerServicing
    private let equalizerTap = PlaybackPCMMonitor()
    private var progressTimer: Timer?
    private var savedProgress: Double = 0
    private var progressRestoreGeneration = 0
    private var storedVolume: Float = 1.0
    private let spectrumHoldDuration: TimeInterval = 0.3
    private var currentURL: URL?
    private var supportsDoP: Bool?
    private var shouldLoop = false
    private var isDoPPlayback = false
    private var isSeekScrubbing = false
    private var wasPlayingBeforeScrub = false
    private var wasPlayingBeforeInterruption = false
    private var isRestoringPlayback = false
    private var isSpectrumFrozenForRestore = false
    private var needsEngineRebuild = false
    private var restoreTargetProgress: Double = 0
    private var restoreSeekRounds = 0
    private var isPausedDueToRouteChange = false
    private var ignoreRoutePauseUntil = Date.distantPast
    private var ignoreAutomaticResumeUntil = Date.distantPast
    private var engineRestoreGeneration = 0
    private var headphonesConnected = false
    private var outputWasExternalAtInterruptionBegan = false
    private var routeWatchTimer: Timer?
    private var lastOutputRouteSignature = ""
    private var isAudioSessionActive = false
    private var unmuteWorkItem: DispatchWorkItem?
    private var outputSilenceGeneration = 0
    private let audioSessionQueue = DispatchQueue(
        label: "com.tunebox.audio-session",
        qos: .userInitiated
    )

    private static let progressInterval: TimeInterval = 0.1
    private static let endThreshold: TimeInterval = 0.05
    private static let progressRestoreTolerance: TimeInterval = 0.25
    private static let progressRestoreRetryInterval: TimeInterval = 0.05
    private static let progressRestoreRetryCount = 24
    private static let progressRestoreMaxRounds = 3
    private static let restoreUnmuteDelay: TimeInterval = 0.08
    private static let skipUnmuteDelay: TimeInterval = 0.12
    private static let userPlaybackRouteGrace: TimeInterval = 1.0
    private static let automaticResumeIgnoreDuration: TimeInterval = 1.5
    private static let progressCaptureFloor: TimeInterval = 0.05
    private static let routeWatchInterval: TimeInterval = 0.03

    private var progressValue: Double {
        guard self.duration > 0 else { return 0 }
        return self.currentTime / self.duration
    }

    private var isNearEnd: Bool {
        guard self.duration > 0 else { return false }
        return (self.duration - self.currentTime) <= Self.endThreshold
    }

    private var isNearStart: Bool {
        self.currentTime <= Self.endThreshold
    }

    private func clampedProgressValue(for deltaSeconds: TimeInterval) -> Double {
        if deltaSeconds >= 0, self.isNearEnd {
            return 1
        }

        if deltaSeconds < 0, self.isNearStart {
            return 0
        }

        return min(max(self.progressValue, 0), 1)
    }

    // MARK: - Methods. Private

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            guard self.shouldIgnoreAutomaticResume().isFalse else {
                return .success
            }

            self.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.player.isPlaying {
                self.pause()
                return .success
            }

            guard self.shouldIgnoreAutomaticResume().isFalse else {
                return .success
            }

            self.resume()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let event = event as? MPChangePlaybackPositionCommandEvent,
                  self.duration > 0 else { return .commandFailed }
            self.seek(to: event.positionTime / self.duration)
            self.refreshNowPlayingElapsed()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onRemotePlayNext?()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.onRemotePlayPrevious?()
            return .success
        }
    }

    private func configureAudioSession() {
        self.activateAudioSession(forceCategory: true)
    }

    private func playDSD(url: URL) throws {
        guard self.isUSBAudioDACConnected() else {
            self.supportsDoP = nil
            try self.playDSDAsPCM(url: url)
            return
        }

        switch self.supportsDoP {
            case .some(true):
                try self.playDSDAsDoP(url: url)

            case .some(false):
                try self.playDSDAsPCM(url: url)

            case .none:
                do {
                    try self.playDSDAsDoP(url: url)
                    self.supportsDoP = true
                    AppLogger.audio.info("Playing DSD via DoP")
                } catch {
                    self.supportsDoP = false
                    AppLogger.audio.warning("DoP unsupported: \(error.localizedDescription)")
                    try self.playDSDAsPCM(url: url)
                }
        }
    }

    private func playDSDAsDoP(url: URL) throws {
        let decoder = try DoPDecoder(url: url)
        try decoder.open()
        try self.startDecoder(decoder)
        self.isDoPPlayback = true
    }

    private func playDSDAsPCM(url: URL) throws {
        let decoder = try DSDPCMDecoder(url: url)
        try decoder.open()
        try self.startDecoder(decoder)
        self.isDoPPlayback = false
    }

    private func startPCMFile(_ url: URL) throws {
        if self.isRestoringPlayback {
            try self.player.enqueue(url, immediate: true)
        } else {
            try self.player.play(url)
        }
    }

    private func startDecoder(_ decoder: PCMDecoding) throws {
        if self.isRestoringPlayback {
            try self.player.enqueue(decoder, immediate: true)
        } else {
            try self.player.play(decoder)
        }
    }

    private func silenceOutput() {
        self.outputSilenceGeneration += 1
        self.unmuteWorkItem?.cancel()
        self.unmuteWorkItem = nil
        self.player.modifyProcessingGraph { engine in
            engine.mainMixerNode.outputVolume = 0
        }
    }

    private func scheduleUnmute() {
        self.unmuteWorkItem?.cancel()

        let generation = self.outputSilenceGeneration
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard generation == self.outputSilenceGeneration else { return }
            guard self.isSeekScrubbing.isFalse, self.isRestoringPlayback.isFalse else { return }
            guard self.player.isPlaying else { return }
            self.applyVolume()
        }

        self.unmuteWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.skipUnmuteDelay,
            execute: work
        )
    }

    private func attachSpectrumIfNeeded() {
        guard self.isDoPPlayback.isFalse else { return }

        self.equalizerTap.remove(from: self.player)
        self.equalizerService.setPlaybackActive(true)
        self.installEqualizerTap(allowRetry: true)
    }

    private func detachEqualizerTap(resetSpectrum: Bool = true) {
        self.equalizerTap.remove(from: self.player)

        if resetSpectrum {
            self.equalizerService.reset()
        } else {
            self.equalizerService.setPlaybackActive(false)
        }
    }

    private func installEqualizerTap(allowRetry: Bool) {
        let installed = self.equalizerTap.install(
            on: self.player,
            bufferSize: self.equalizerService.hopSize
        ) { [weak self] buffer in
            self?.equalizerService.process(buffer)
        }

        guard installed.isFalse, allowRetry else { return }

        DispatchQueue.main.async { [weak self] in
            self?.installEqualizerTap(allowRetry: false)
        }
    }

    private func isUSBAudioDACConnected() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs
            .contains { $0.portType == .usbAudio }
    }

    private func startProgressTimer() {
        self.stopProgressTimer()
        self.startRouteWatch()
        let timer = Timer(timeInterval: Self.progressInterval, repeats: true) { [weak self] _ in
            guard let self, self.player.isPlaying, self.duration > 0 else { return }
            guard self.isRestoringPlayback.isFalse else { return }
            self.notifyProgress(self.progressValue)
            self.refreshNowPlayingElapsed()
        }
        self.progressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopProgressTimer() {
        self.progressTimer?.invalidate()
        self.progressTimer = nil
        self.stopRouteWatch()
    }

    private func notifyStateChange(_ playing: Bool) {
        if playing, self.isPausedDueToRouteChange {
            return
        }

        if Thread.isMainThread {
            self.stateChangeSubject.send(playing)
        } else {
            DispatchQueue.main.async {
                self.stateChangeSubject.send(playing)
            }
        }
    }

    private func notifyProgress(_ progress: Double) {
        let clamped = min(max(progress, 0), 1)

        if self.isRestoringPlayback {
            DispatchQueue.main.async {
                self.progressSubject.send(self.restoreTargetProgress)
            }
            return
        }

        if clamped > 0 || self.player.currentTime != nil {
            self.savedProgress = clamped
        }

        DispatchQueue.main.async {
            self.progressSubject.send(clamped)
        }
    }

    private func captureProgress() {
        guard let currentTime = self.player.currentTime, self.duration > 0 else {
            return
        }

        // A route/engine teardown often reports 0 while the real pause
        // position is already in savedProgress. Don't clobber it.
        if currentTime < Self.progressCaptureFloor, self.savedProgress > 0 {
            return
        }

        self.savedProgress = min(max(currentTime / self.duration, 0), 1)
    }

    private func cancelPendingProgressRestore() {
        self.progressRestoreGeneration += 1
    }

    @discardableResult
    private func restoreCurrentTrack() -> Bool {
        guard let url = self.currentURL, let trackId = self.currentTrackId else {
            return false
        }

        let progressToRestore = self.savedProgress
        AppLogger.audio.info(
            "Restoring playback at progress \(progressToRestore) for \(trackId)"
        )
        self.beginRestore(to: progressToRestore)
        self.play(trackId: trackId, url: url, loop: self.shouldLoop)
        self.seekWhenReady(to: progressToRestore)
        return true
    }

    private func restoreProgressIfNeeded() {
        guard self.isRestoringPlayback.isFalse else { return }
        guard self.savedProgress > 0, self.savedProgress < 1, self.duration > 0 else {
            return
        }

        let savedTime = self.savedProgress * self.duration
        let currentTime = self.player.currentTime ?? 0
        guard abs(currentTime - savedTime) > Self.progressRestoreTolerance else {
            return
        }

        AppLogger.audio.info(
            "Playback position reset to \(currentTime)s; restoring \(savedTime)s"
        )
        self.beginRestore(to: self.savedProgress)
        self.seekWhenReady(to: self.savedProgress)
    }

    private func seekWhenReady(to progress: Double) {
        guard progress > 0, progress < 1 else {
            self.finishRestore()
            return
        }

        self.cancelPendingProgressRestore()
        let generation = self.progressRestoreGeneration
        self.attemptProgressRestore(
            to: progress,
            generation: generation,
            attemptsLeft: Self.progressRestoreRetryCount
        )
    }

    private func attemptProgressRestore(to progress: Double, generation: Int, attemptsLeft: Int) {
        guard generation == self.progressRestoreGeneration else { return }

        if self.player.seek(position: progress) {
            self.notifyProgress(progress)
            self.refreshNowPlayingElapsed()
            self.scheduleRestoreCompletion(
                targetProgress: progress,
                generation: generation,
                attemptsLeft: Self.progressRestoreRetryCount
            )
            return
        }

        guard attemptsLeft > 0 else {
            AppLogger.audio.warning(
                "Failed to restore playback progress \(progress) after route/engine reset"
            )
            self.finishRestore()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.progressRestoreRetryInterval) { [weak self] in
            self?.attemptProgressRestore(
                to: progress,
                generation: generation,
                attemptsLeft: attemptsLeft - 1
            )
        }
    }

    private func scheduleRestoreCompletion(
        targetProgress: Double,
        generation: Int,
        attemptsLeft: Int
    ) {
        guard generation == self.progressRestoreGeneration else { return }
        guard self.isRestoringPlayback else { return }

        if self.hasReached(progress: targetProgress) {
            self.finishRestore()
            return
        }

        guard attemptsLeft > 0 else {
            if self.restoreSeekRounds < Self.progressRestoreMaxRounds {
                self.restoreSeekRounds += 1
                self.attemptProgressRestore(
                    to: targetProgress,
                    generation: generation,
                    attemptsLeft: Self.progressRestoreRetryCount
                )
                return
            }

            self.finishRestore()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.progressRestoreRetryInterval) { [weak self] in
            self?.scheduleRestoreCompletion(
                targetProgress: targetProgress,
                generation: generation,
                attemptsLeft: attemptsLeft - 1
            )
        }
    }

    private func hasReached(progress: Double) -> Bool {
        guard self.duration > 0 else { return false }

        let targetTime = progress * self.duration
        let currentTime = self.player.currentTime ?? 0
        return abs(currentTime - targetTime) <= Self.progressRestoreTolerance
    }

    private func beginRestore(to progress: Double) {
        self.isRestoringPlayback = true
        self.restoreTargetProgress = min(max(progress, 0), 1)
        self.restoreSeekRounds = 0
        self.needsEngineRebuild = false
        self.freezeSpectrumForRestore()
        self.silenceOutput()
        self.applyVolume()
    }

    private func cancelRestore() {
        guard self.isRestoringPlayback || self.isSpectrumFrozenForRestore else { return }

        self.isRestoringPlayback = false
        self.unfreezeSpectrumAfterRestore()
    }

    private func finishRestore() {
        let shouldUnmute = self.isRestoringPlayback
        guard shouldUnmute else {
            self.unfreezeSpectrumAfterRestore()
            return
        }

        self.silenceOutput()

        if self.player.isPlaying.isFalse {
            do {
                try self.player.play()
            } catch {
                AppLogger.audio.error(
                    "Failed to start restored playback: \(error.localizedDescription)"
                )
            }
        }

        self.attachSpectrumIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restoreUnmuteDelay) { [weak self] in
            guard let self, self.isRestoringPlayback else { return }

            self.isRestoringPlayback = false
            self.applyVolume()
            self.unfreezeSpectrumAfterRestore()

            let progress = self.restoreTargetProgress
            if progress > 0, progress < 1 {
                self.savedProgress = progress
                self.progressSubject.send(progress)
            }
            self.refreshNowPlayingElapsed()
        }
    }

    private func freezeSpectrumForRestore() {
        guard self.isSpectrumFrozenForRestore.isFalse else { return }

        self.isSpectrumFrozenForRestore = true
        self.equalizerService.holdUpdates()
    }

    private func unfreezeSpectrumAfterRestore() {
        guard self.isSpectrumFrozenForRestore else { return }

        self.isSpectrumFrozenForRestore = false
        self.equalizerService.resumeUpdates()
    }

    private func clampVolume(_ value: Float) -> Float {
        max(0, min(1, value))
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereLostNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleOutputDropout),
            name: .playbackOutputDropoutDetected,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    private func activateAudioSession(forceCategory: Bool = false) {
        self.audioSessionQueue.async { [weak self] in
            self?.performAudioSessionActivation(forceCategory: forceCategory)
        }
    }

    private func performAudioSessionActivation(forceCategory: Bool) {
        let session = AVAudioSession.sharedInstance()
        let needsCategory = forceCategory
            || session.category != .playback
            || session.mode != .default

        if needsCategory, forceCategory || self.isAudioSessionActive.isFalse {
            do {
                try session.setCategory(.playback, mode: .default)
            } catch {
                AppLogger.audio.error(
                    "Failed to configure audio session: \(error.localizedDescription)"
                )
            }
        }

        guard self.isAudioSessionActive.isFalse else { return }

        if #available(iOS 27.0, *) {
            session.activate(options: []) { [weak self] success, error in
                if let error {
                    AppLogger.audio.error(
                        "Failed to activate audio session: \(error.localizedDescription)"
                    )
                }

                self?.runOnMain {
                    self?.isAudioSessionActive = success
                }
            }
            return
        }

        do {
            try session.setActive(true)
            self.runOnMain {
                self.isAudioSessionActive = true
            }
        } catch {
            AppLogger.audio.error(
                "Failed to activate audio session: \(error.localizedDescription)"
            )
        }
    }

    private func resumeAfterInterruption() {
        self.resume()
    }

    private func refreshNowPlayingElapsed() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? 1.0 : 0.0

        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func applyVolume() {
        let volume: Float

        if self.isSeekScrubbing || self.isRestoringPlayback {
            volume = 0
        } else {
            volume = self.isDoPPlayback ? 1.0 : self.storedVolume
        }

        self.player.modifyProcessingGraph { engine in
            engine.mainMixerNode.outputVolume = volume
        }
    }

    private func endSeekScrubbingIfNeeded() {
        let shouldResume = self.wasPlayingBeforeScrub
        let wasScrubbing = self.isSeekScrubbing

        self.isSeekScrubbing = false
        self.wasPlayingBeforeScrub = false

        if wasScrubbing {
            self.equalizerService.resumeUpdates()
        }

        self.applyVolume()

        guard wasScrubbing || shouldResume else { return }
        guard shouldResume, self.player.isPlaying.isFalse else { return }

        if self.needsEngineRebuild.isFalse, self.player.resume() {
            self.equalizerService.setPlaybackActive(true)
            self.startProgressTimer()
            self.notifyStateChange(true)
            self.refreshNowPlayingElapsed()
            self.restoreProgressIfNeeded()
            return
        }

        _ = self.restoreCurrentTrack()
    }

    private func pauseForRouteChange() {
        guard self.currentTrackId != nil else { return }

        self.freezeSpectrumForRestore()
        self.pauseEngineImmediately()
        self.publishPausedForRouteChange()
    }

    private func publishPausedForRouteChange() {
        self.equalizerService.setPlaybackActive(false)
        self.stopProgressTimer()
        self.notifyStateChange(false)
        NotificationCenter.default.post(name: .playbackDidPauseForRouteChange, object: nil)
        self.refreshNowPlayingElapsed()
    }

    private func pauseEngineImmediately() {
        self.equalizerService.stopProcessing()
        self.isPausedDueToRouteChange = true
        self.wasPlayingBeforeInterruption = false
        self.forbidEnginePlaybackRestore()
        self.ignoreAutomaticResumeUntil = Date().addingTimeInterval(Self.automaticResumeIgnoreDuration)
        self.needsEngineRebuild = true
        self.captureProgress()
        self.silenceOutput()
        _ = self.player.pause()
        self.notifyStateChange(false)
        self.stopRouteWatch()
        NotificationCenter.default.post(name: .playbackDidPauseForRouteChange, object: nil)
    }

    private func startRouteWatch() {
        self.stopRouteWatch()
        self.lastOutputRouteSignature = self.currentOutputRouteSignature()
        self.checkHeadphonesConnection(
            outputs: AVAudioSession.sharedInstance().currentRoute.outputs
        )

        let timer = Timer(timeInterval: Self.routeWatchInterval, repeats: true) { [weak self] _ in
            self?.checkOutputRouteForPause()
        }
        self.routeWatchTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopRouteWatch() {
        self.routeWatchTimer?.invalidate()
        self.routeWatchTimer = nil
    }

    private func currentOutputRouteSignature() -> String {
        AVAudioSession.sharedInstance().currentRoute.outputs
            .map { "\($0.portType.rawValue):\($0.uid)" }
            .sorted()
            .joined(separator: "|")
    }

    private func checkOutputRouteForPause() {
        guard self.currentTrackId != nil else { return }
        guard Date() >= self.ignoreRoutePauseUntil, self.isRestoringPlayback.isFalse else {
            self.lastOutputRouteSignature = self.currentOutputRouteSignature()
            return
        }
        guard self.isPausedDueToRouteChange.isFalse else { return }

        let signature = self.currentOutputRouteSignature()
        if self.lastOutputRouteSignature.isEmpty {
            self.lastOutputRouteSignature = signature
            return
        }

        guard signature != self.lastOutputRouteSignature else { return }
        self.lastOutputRouteSignature = signature
        self.pauseForRouteChange()
    }

    @objc
    private func handleOutputDropout(_ notification: Notification) {
        guard self.currentTrackId != nil else { return }
        guard Date() >= self.ignoreRoutePauseUntil, self.isRestoringPlayback.isFalse else { return }
        guard self.isPausedDueToRouteChange.isFalse else { return }

        self.runOnMain {
            self.pauseForRouteChange()
        }
    }

    private func allowEnginePlaybackRestore() {
        self.engineRestoreGeneration += 1
        let generation = self.engineRestoreGeneration
        self.player.restoresPlaybackAfterEngineReset = true
        self.ignoreRoutePauseUntil = Date().addingTimeInterval(Self.userPlaybackRouteGrace)

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.userPlaybackRouteGrace) { [weak self] in
            guard let self, generation == self.engineRestoreGeneration else { return }
            self.player.restoresPlaybackAfterEngineReset = false
        }
    }

    private func forbidEnginePlaybackRestore() {
        self.engineRestoreGeneration += 1
        self.player.restoresPlaybackAfterEngineReset = false
        self.ignoreRoutePauseUntil = .distantPast
    }

    private func shouldPauseForRouteChange(
        _ notification: Notification,
        reason: AVAudioSession.RouteChangeReason
    ) -> Bool {
        switch reason {
            case .oldDeviceUnavailable, .newDeviceAvailable:
                return true

            case .routeConfigurationChange:
                let previous = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey]
                    as? AVAudioSessionRouteDescription
                let hadExternal = previous?.outputs.contains { self.isExternalOutput($0.portType) } ?? false
                let hasExternal = AVAudioSession.sharedInstance().currentRoute.outputs
                    .contains { self.isExternalOutput($0.portType) }

                return hadExternal != hasExternal

            default:
                return false
        }
    }

    private func shouldIgnoreAutomaticResume() -> Bool {
        self.isPausedDueToRouteChange || Date() < self.ignoreAutomaticResumeUntil
    }

    private var shouldIgnoreRoutePause: Bool {
        Date() < self.ignoreRoutePauseUntil || self.isRestoringPlayback
    }

    private func checkHeadphonesConnection(outputs: [AVAudioSessionPortDescription]) {
        self.headphonesConnected = outputs.contains { self.isExternalOutput($0.portType) }
    }

    private func isExternalOutput(_ portType: AVAudioSession.Port) -> Bool {
        portType == .headphones
            || portType == .bluetoothA2DP
            || portType == .bluetoothHFP
            || portType == .bluetoothLE
            || portType == .usbAudio
            || portType == .carAudio
            || portType == .airPlay
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func logAudioRoute() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs

        for output in outputs {
            AppLogger.audio.info(
                "Audio output: \(output.portName), type: \(output.portType.rawValue)"
            )
        }
    }

    private func updateSourceFormat(for url: URL) {
        let format = url.pathExtension.uppercased()
        var parts: [String] = []

        if let file = try? AudioFile(readingPropertiesAndMetadataFrom: url) {
            let props = file.properties

            if let bits = props.bitDepth {
                parts.append("\(bits) bit")
            } else if let bitrate = props.bitrate, bitrate > 0 {
                parts.append("\(Int(bitrate.rounded())) kbps")
            }

            if let rate = props.sampleRate {
                parts.append("\(Int((rate / 1000).rounded())) kHz")
            }
        }

        parts.append(format.isEmpty ? "AUDIO" : format)
        self.sourceFormatText = parts.joined(separator: " • ")
        self.publishFormatInfo()
    }

    private func updateOutputRoute() {
        let session = AVAudioSession.sharedInstance()
        let name = session.currentRoute.outputs.first?.portName ?? "Speaker"
        let kHz = Int((session.sampleRate / 1000).rounded())
        self.outputRouteText = "\(name) • \(kHz) kHz"
        self.publishFormatInfo()
    }

    private func publishFormatInfo() {
        self.formatInfoSubject.send((self.sourceFormatText, self.outputRouteText))
    }

    // MARK: - Events

    @objc
    private func handleAudioInterruption(_ notification: Notification) {
        guard
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        if type == .began {
            self.outputWasExternalAtInterruptionBegan = AVAudioSession.sharedInstance().currentRoute.outputs
                .contains { self.isExternalOutput($0.portType) }

            if self.isPausedDueToRouteChange.isFalse,
               self.player.isPlaying || self.stateChangeSubject.value {
                self.equalizerService.stopProcessing()
                self.silenceOutput()
                _ = self.player.pause()
                self.notifyStateChange(false)
                NotificationCenter.default.post(name: .playbackDidPauseForRouteChange, object: nil)
            }
        }

        self.runOnMain {
            self.handleAudioInterruptionOnMain(notification)
        }
    }

    private func handleAudioInterruptionOnMain(_ notification: Notification) {
        guard
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        switch type {
            case .began:
                self.isAudioSessionActive = false

                if self.isPausedDueToRouteChange {
                    self.wasPlayingBeforeInterruption = false
                    self.needsEngineRebuild = true
                    self.captureProgress()
                    return
                }

                let wasPlaying = self.player.isPlaying || self.stateChangeSubject.value
                self.wasPlayingBeforeInterruption = wasPlaying
                self.needsEngineRebuild = true
                self.captureProgress()

                if wasPlaying {
                    self.pause(captureProgress: false)
                }

            case .ended:
                let hasExternal = AVAudioSession.sharedInstance().currentRoute.outputs
                    .contains { self.isExternalOutput($0.portType) }

                if self.outputWasExternalAtInterruptionBegan != hasExternal {
                    self.wasPlayingBeforeInterruption = false
                    self.pauseForRouteChange()
                    return
                }

                guard self.wasPlayingBeforeInterruption else {
                    return
                }

                if self.shouldIgnoreAutomaticResume() {
                    self.wasPlayingBeforeInterruption = false
                    return
                }

                let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

                if options.contains(.shouldResume) {
                    self.wasPlayingBeforeInterruption = false
                    self.resumeAfterInterruption()
                }

            @unknown default:
                break
        }
    }

    @objc
    private func handleAppDidBecomeActive(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wasPlayingBeforeInterruption else { return }
            guard self.shouldIgnoreAutomaticResume().isFalse else {
                self.wasPlayingBeforeInterruption = false
                return
            }

            self.wasPlayingBeforeInterruption = false
            self.resumeAfterInterruption()
        }
    }

    @objc
    private func handleMediaServicesReset(_ notification: Notification) {
        self.pauseEngineImmediately()
        self.runOnMain {
            self.isAudioSessionActive = false
            self.activateAudioSession(forceCategory: true)
            self.publishPausedForRouteChange()
        }
    }

    @objc
    private func audioRouteChanged(_ notification: Notification) {
        guard
            let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: value)
        else {
            return
        }

        let shouldPause = self.shouldPauseForRouteChange(notification, reason: reason)
            && self.shouldIgnoreRoutePause.isFalse

        if shouldPause {
            self.pauseEngineImmediately()
        }

        self.runOnMain {
            self.handleAudioRouteChangeOnMain(
                reason: reason,
                notification: notification,
                shouldPause: shouldPause
            )
        }
    }

    private func handleAudioRouteChangeOnMain(
        reason: AVAudioSession.RouteChangeReason,
        notification: Notification,
        shouldPause: Bool
    ) {
        AppLogger.audio.info(
            "Audio route changed: \(reason.rawValue), headphones: \(self.headphonesConnected), stopped: \(self.player.isStopped)"
        )

        switch reason {
            case .newDeviceAvailable,
                    .oldDeviceUnavailable,
                    .routeConfigurationChange:
                self.checkHeadphonesConnection(
                    outputs: AVAudioSession.sharedInstance().currentRoute.outputs
                )
                self.supportsDoP = nil
                self.needsEngineRebuild = true
                self.updateOutputRoute()

                if shouldPause {
                    self.pauseForRouteChange()
                }

            default:
                break
        }
    }
}

// MARK: - AudioPlayer.Delegate

extension AudioService: AudioPlayer.Delegate {

    func audioPlayer(_ audioPlayer: AudioPlayer, playbackStateChanged playbackState: AudioPlayer.PlaybackState) {
        switch playbackState {
            case .playing:
                if self.isPausedDueToRouteChange || self.shouldIgnoreAutomaticResume() {
                    self.pauseEngineImmediately()
                    self.runOnMain {
                        self.publishPausedForRouteChange()
                    }
                    return
                }

                self.notifyStateChange(true)
                self.startProgressTimer()
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.isRestoringPlayback.isFalse else { return }
                    self.restoreProgressIfNeeded()
                }

            case .paused, .stopped:
                guard self.isRestoringPlayback.isFalse else { return }
                self.notifyStateChange(false)
                self.stopProgressTimer()

            @unknown default:
                break
        }
    }

    func audioPlayer(
        _ audioPlayer: AudioPlayer,
        audioEngineConfigurationWillChange userInfo: [AnyHashable: Any]?
    ) {
        if self.shouldIgnoreRoutePause {
            return
        }

        self.pauseEngineImmediately()
    }

    func audioPlayer(
        _ audioPlayer: AudioPlayer,
        audioEngineConfigurationChange userInfo: [AnyHashable: Any]?
    ) {
        let hadExternal = self.headphonesConnected
        let hasExternal = AVAudioSession.sharedInstance().currentRoute.outputs
            .contains { self.isExternalOutput($0.portType) }
        self.checkHeadphonesConnection(
            outputs: AVAudioSession.sharedInstance().currentRoute.outputs
        )

        if self.isPausedDueToRouteChange {
            self.pauseEngineImmediately()
            self.runOnMain {
                self.pauseForRouteChange()
            }
            return
        }

        if Date() < self.ignoreRoutePauseUntil || self.isRestoringPlayback {
            self.runOnMain {
                self.attachSpectrumIfNeeded()
                self.applyVolume()
            }
            return
        }

        if hadExternal != hasExternal {
            self.pauseEngineImmediately()
            self.runOnMain {
                self.pauseForRouteChange()
            }
        }
    }

    func audioPlayerEndOfAudio(_ audioPlayer: AudioPlayer) {
        AppLogger.audio.info("AudioService END: \(self.currentTrackId ?? "nil")")
        self.onTrackFinished?()
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, encounteredError error: any Error) {
        AppLogger.audio.error("SFB player error: \(error.localizedDescription)")
        self.captureProgress()
        self.needsEngineRebuild = true
        self.detachEqualizerTap(resetSpectrum: false)
        self.player.stop()
        self.equalizerService.setPlaybackActive(false)
        self.stopProgressTimer()
        self.notifyStateChange(false)
        self.refreshNowPlayingElapsed()
    }

}
