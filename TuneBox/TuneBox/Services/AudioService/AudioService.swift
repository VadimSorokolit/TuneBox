//
//  AudioService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 21.05.2026.
//

import Foundation
import AVFoundation
import Combine
import os

final class AudioService: NSObject, AudioServicing, AVAudioPlayerDelegate {

    // MARK: - Properties. Public

    static let shared: AudioService = AudioService()
    private(set) var currentTrackId: String?
    private(set) var stateChangeSubject = CurrentValueSubject<Bool, Never>(false)
    private(set) var progressSubject = PassthroughSubject<Double, Never>()

    var duration: TimeInterval {
        self.mainPlayer?.duration ?? 0
    }

    var currentTime: TimeInterval {
        self.mainPlayer?.currentTime ?? 0
    }

    var volume: Float {
        get {
            self.storedVolume
        }
        set {
            self.storedVolume = self.clampVolume(newValue)
            self.mainPlayer?.volume = self.storedVolume
        }
    }

    // MARK: - Initializer

    private override init() {
        super.init()

        self.configureAudioSession()
        self.setupAudioSessionObservers()
    }

    // MARK: - Methods. Public

    func play(trackId: String, url: URL, loop: Bool = false) {
        self.stopMainPlayer()

        do {
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.numberOfLoops = loop ? -1 : 0
            player.volume = self.storedVolume
            player.delegate = self

            self.mainPlayer = player
            self.currentTrackId = trackId

            player.play()

            self.notifyStateChange(true)
            self.startProgressTimer()
        } catch {
            AppLogger.audio.error("Failed to play audio: \(String(describing: error))")
        }
    }

    func pause() {
        self.mainPlayer?.pause()
        self.stopProgressTimer()
        self.notifyStateChange(false)
    }

    func resume() {
        guard let player = self.mainPlayer else {
            return
        }

        player.play()
        self.startProgressTimer()
        self.notifyStateChange(true)
    }

    func stop() {
        self.stopMainPlayer()
        self.stopProgressTimer()
        self.currentTrackId = nil
        self.notifyStateChange(false)
        self.notifyProgress(0)
    }

    func toggle(trackId: String, url: URL, loop: Bool = false) {
        if self.currentTrackId != trackId {
            self.play(trackId: trackId, url: url, loop: loop)

            return
        }

        guard let player = self.mainPlayer else {
            self.play(trackId: trackId, url: url, loop: loop)

            return
        }

        if self.isNearEnd(player) {
            self.stop()

            return
        }

        if self.stateChangeSubject.value == true {
            self.pause()
        } else {
            self.resume()
        }
    }

    func seek(by deltaSeconds: TimeInterval) {
        guard let player = self.mainPlayer, player.duration > 0 else {
            return
        }

        let newTime = max(0, min(player.duration, player.currentTime + deltaSeconds))
        player.currentTime = newTime

        self.notifyProgress(newTime / player.duration)
    }

    func seek(to progress: Double) {
        guard let player = self.mainPlayer, player.duration > 0 else {
            return
        }

        let clamped = min(max(progress, 0), 1)
        player.currentTime = clamped * player.duration

        self.notifyProgress(clamped)
    }

    func playEffect(name: String, ext: AudioFileExtension = .mp3) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext.rawValue) else {
            AppLogger.audio.error("Effect file not found: \(name).\(ext.rawValue)")

            return
        }

        self.effectPlayer?.stop()
        self.effectPlayer = nil

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()

            self.effectPlayer = player
        } catch {
            AppLogger.audio.error("Failed to play effect: \(String(describing: error))")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === self.mainPlayer else {
            return
        }

        self.stop()
    }

    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            AppLogger.audio.error("Failed to configure audio session: \(String(describing: error))")
        }
    }

    // MARK: - Properties. Private

    private var mainPlayer: AVAudioPlayer?
    private var effectPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var storedVolume: Float = 1.0
    private static let progressInterval: TimeInterval = 0.1
    private static let endThreshold: TimeInterval = 0.05

    // MARK: - Methods. Private

    private func setupAudioSessionObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    private func stopMainPlayer() {
        self.mainPlayer?.stop()
        self.mainPlayer = nil
    }

    private func isNearEnd(_ player: AVAudioPlayer) -> Bool {
        (player.duration - player.currentTime) <= Self.endThreshold
    }

    private func startProgressTimer() {
        self.stopProgressTimer()

        let timer = Timer(
            timeInterval: Self.progressInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self,
                  let player = self.mainPlayer,
                  player.duration > 0,
                  self.stateChangeSubject.value  == true
            else {
                return
            }

            self.notifyProgress(player.currentTime / player.duration)
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
                self.pause()

            case .ended:
                break

            @unknown default:
                break
        }
    }

    @objc
    private func handleAudioRouteChange(_ notification: Notification) {
        guard
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else {
            return
        }

        if reason == .oldDeviceUnavailable {
            self.pause()
        }
    }
}
