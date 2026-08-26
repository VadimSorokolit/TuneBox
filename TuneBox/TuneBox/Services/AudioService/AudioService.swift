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
import UIKit

final class AudioService: NSObject, AudioServicing {

    // MARK: - Properties. Public

    static let shared = AudioService()

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

    // MARK: - Initializer

    private override init() {
        super.init()
        self.setupObservers()
        self.player.delegate = self
        self.configureAudioSession()
        self.configureRemoteCommands()
    }

    // MARK: - Methods. Public

    func play(trackId: String, url: URL, loop: Bool = false) {
        AppLogger.audio.info("AudioService PLAY: \(trackId)")

        self.stopProgressTimer()
        self.currentTrackId = trackId
        self.currentURL = url
        self.shouldLoop = loop

        do {
            let ext = url.pathExtension.lowercased()
            let isDSD = ext == AudioFileExtension.dsf.rawValue
            || ext == AudioFileExtension.dff.rawValue

            if isDSD {
                try self.playDSD(url: url)
            } else {
                try self.player.play(url)
                self.isDoPPlayback = false
            }

            self.applyVolume()
            self.notifyStateChange(true)
            self.startProgressTimer()
            self.refreshFormatInfo(for: url)
            self.refreshNowPlayingElapsed()
        } catch {
            AppLogger.audio.error("Failed to play audio: \(error.localizedDescription)")
            self.notifyStateChange(false)
            self.isDoPPlayback = false
        }
    }

    func pause() {
        _ = self.player.pause()
        self.stopProgressTimer()
        self.notifyStateChange(false)
        self.refreshNowPlayingElapsed()
    }

    func resume() {
        guard self.player.resume() else { return }
        self.startProgressTimer()
        self.notifyStateChange(true)
        self.refreshNowPlayingElapsed()
    }

    func stop() {
        self.player.stop()
        self.stopProgressTimer()
        self.currentTrackId = nil
        self.currentURL = nil
        self.isDoPPlayback = false
        self.shouldLoop = false
        self.isSeekScrubbing = false
        self.wasPlayingBeforeInterruption = false
        self.interruptedProgress = 0
        self.notifyStateChange(false)
        self.notifyProgress(0)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func restartCurrentTrack() {
        guard let url = self.currentURL, let trackId = self.currentTrackId else { return }

        if self.player.seek(position: 0) {
            self.notifyProgress(0)

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

        self.play(trackId: trackId, url: url, loop: self.shouldLoop)
    }

    func toggle(trackId: String, url: URL, loop: Bool = false) {
        AppLogger.audio.info("AudioService TOGGLE: \(trackId), current: \(self.currentTrackId ?? "nil")")

        if self.currentTrackId != trackId {
            self.play(trackId: trackId, url: url, loop: loop)
            return
        }

        if self.player.isStopped {
            self.play(trackId: trackId, url: url, loop: loop)
            return
        }

        if self.isNearEnd {
            self.stop()
            return
        }

        if self.player.isPlaying {
            self.pause()
        } else {
            self.resume()
        }
    }

    func seek(by deltaSeconds: TimeInterval) {
        guard self.duration > 0 else { return }

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
        self.isSeekScrubbing = isScrubbing
        self.applyVolume()
    }

    func refreshFormatInfo(for url: URL) {
        self.updateSourceFormat(for: url)
        self.updateOutputRoute()
    }

    func seek(to progress: Double) {
        guard self.duration > 0 else { return }
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

        if let coverImage = self.coverImage(from: track) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: coverImage.size) { _ in
                coverImage
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Properties. Private

    private let player = AudioPlayer()
    private let effectPlayer = AudioPlayer()
    private var progressTimer: Timer?
    private var storedVolume: Float = 1.0
    private var currentURL: URL?
    private var shouldLoop = false
    private var isDoPPlayback = false
    private var supportsDoP: Bool?
    private var isSeekScrubbing = false
    private var wasPlayingBeforeInterruption = false
    private var interruptedProgress: Double = 0

    private static let progressInterval: TimeInterval = 0.1
    private static let endThreshold: TimeInterval = 0.05

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
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.player.isPlaying { self.pause() } else { self.resume() }
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
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            AppLogger.audio.error("Failed to configure audio session: \(error.localizedDescription)")
        }
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
        try self.player.play(decoder)
        self.isDoPPlayback = true
    }

    private func playDSDAsPCM(url: URL) throws {
        let decoder = try DSDPCMDecoder(url: url)
        try decoder.open()
        try self.player.play(decoder)
        self.isDoPPlayback = false
    }

    private func isUSBAudioDACConnected() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs
            .contains { $0.portType == .usbAudio }
    }

    private func coverImage(from track: TrackEntity) -> UIImage? {
        guard let path = track.imagePath, !path.isEmpty else { return nil }

        if path.hasPrefix("http://") || path.hasPrefix("https://"),
           let url = URL(string: path),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }

        if let url = AudioMetadataService.coverURL(for: path),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }

        return nil
    }

    private func startProgressTimer() {
        self.stopProgressTimer()
        let timer = Timer(timeInterval: Self.progressInterval, repeats: true) { [weak self] _ in
            guard let self, self.player.isPlaying, self.duration > 0 else { return }
            self.notifyProgress(self.progressValue)
            self.refreshNowPlayingElapsed()
        }
        self.progressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopProgressTimer() {
        self.progressTimer?.invalidate()
        self.progressTimer = nil
    }

    private func notifyStateChange(_ playing: Bool) {
        DispatchQueue.main.async {
            self.stateChangeSubject.send(playing)
        }
    }

    private func notifyProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.progressSubject.send(progress)
        }
    }

    private func clampVolume(_ value: Float) -> Float {
        max(0, min(1, value))
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    private func resumeAfterInterruption() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            AppLogger.audio.error(
                "Failed to reactivate audio session: \(error.localizedDescription)"
            )
            return
        }

        if self.player.resume() {
            self.startProgressTimer()
            self.notifyStateChange(true)
            self.refreshNowPlayingElapsed()
            return
        }

        guard let url = self.currentURL, let trackId = self.currentTrackId else {
            return
        }

        let progressToRestore = self.interruptedProgress
        self.play(trackId: trackId, url: url, loop: self.shouldLoop)

        if progressToRestore > 0 {
            _ = self.player.seek(position: progressToRestore)
            self.notifyProgress(progressToRestore)
            self.refreshNowPlayingElapsed()
        }
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

        if self.isSeekScrubbing {
            volume = 0
        } else if self.isDoPPlayback {
            volume = 1.0
        } else {
            volume = self.storedVolume
        }

        self.player.modifyProcessingGraph { engine in
            engine.mainMixerNode.outputVolume = volume
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

        switch type {
            case .began:
                let wasPlaying = self.player.isPlaying || self.stateChangeSubject.value
                self.wasPlayingBeforeInterruption = wasPlaying
                self.interruptedProgress = min(max(self.progressValue, 0), 1)

                if wasPlaying {
                    self.pause()
                }

            case .ended:
                guard self.wasPlayingBeforeInterruption else {
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
        guard self.wasPlayingBeforeInterruption else {
            return
        }

        self.wasPlayingBeforeInterruption = false
        self.resumeAfterInterruption()
    }

    @objc
    private func audioRouteChanged(_ notification: Notification) {
        guard
            let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: value)
        else {
            return
        }

        switch reason {
            case .newDeviceAvailable,
                    .oldDeviceUnavailable,
                    .routeConfigurationChange:
                self.supportsDoP = nil
                self.updateOutputRoute()

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
                self.notifyStateChange(true)
                self.startProgressTimer()

            case .paused, .stopped:
                self.notifyStateChange(false)
                self.stopProgressTimer()

            @unknown default:
                break
        }
    }

    func audioPlayerEndOfAudio(_ audioPlayer: AudioPlayer) {
        AppLogger.audio.info("AudioService END: \(self.currentTrackId ?? "nil")")
        self.onTrackFinished?()
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, encounteredError error: any Error) {
        AppLogger.audio.error("SFB player error: \(error.localizedDescription)")
        self.stop()
    }

}
