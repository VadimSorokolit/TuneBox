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

    static let shared = AudioService()

    private(set) var currentTrackId: String?
    private(set) var stateChangeSubject = CurrentValueSubject<Bool, Never>(false)
    private(set) var progressSubject = PassthroughSubject<Double, Never>()
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
        self.stopProgressTimer()
        self.currentTrackId = trackId
        self.shouldLoop = loop
        self.loopURL = loop ? url : nil

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
        self.isDoPPlayback = false
        self.shouldLoop = false
        self.loopURL = nil
        self.notifyStateChange(false)
        self.notifyProgress(0)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func toggle(trackId: String, url: URL, loop: Bool = false) {
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

        self.notifyProgress(progressValue)
        self.refreshNowPlayingElapsed()
    }

    func seek(to progress: Double) {
        guard self.duration > 0 else { return }
        let clamped = min(max(progress, 0), 1)
        _ = self.player.seek(position: clamped)
        self.notifyProgress(clamped)
        self.refreshNowPlayingElapsed()
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
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.songName,
            MPMediaItemPropertyArtist: track.artistName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0
        ]

        if self.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if let artwork = self.artworkImage(from: track) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                artwork
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Properties. Private

    private let player = AudioPlayer()
    private let effectPlayer = AudioPlayer()
    private var progressTimer: Timer?
    private var storedVolume: Float = 1.0
    private var loopURL: URL?
    private var shouldLoop = false
    private var isDoPPlayback = false
    private var supportsDoP: Bool?

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

    private func artworkImage(from track: TrackEntity) -> UIImage? {
        guard let path = track.imagePath, !path.isEmpty else { return nil }

        if path.hasPrefix("http://") || path.hasPrefix("https://"),
           let url = URL(string: path),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }

        if let url = AudioMetadataService.artworkURL(for: path),
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
            selector: #selector(self.audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
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
        let volume = self.isDoPPlayback ? 1.0 : self.storedVolume
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
    
    // MARK: - Events

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
        if self.shouldLoop, let loopURL, let trackId = currentTrackId {
            self.play(trackId: trackId, url: loopURL, loop: true)
            return
        }
        self.onTrackFinished?()
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, encounteredError error: any Error) {
        AppLogger.audio.error("SFB player error: \(error.localizedDescription)")
        self.stop()
    }

}
