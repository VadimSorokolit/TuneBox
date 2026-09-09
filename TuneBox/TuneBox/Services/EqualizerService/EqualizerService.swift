//
//  EqualizerService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 09.09.2026.
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class EqualizerService: EqualizerServicing {

    // MARK: - Properties. Public

    nonisolated var hopSize: AVAudioFrameCount {
        AVAudioFrameCount(SpectrumAnalyzer.hopSize)
    }

    var bandCount: Int {
        Self.bandCount
    }

    var bandCenters: [Float] {
        Self.bandCenters
    }

    /// Normalized RTA values for UI: 0 ... 1
    private(set) var bands: [Float]

    /// Smoothed 1/3-octave levels in dBFS
    private(set) var decibels: [Float]

    // MARK: - Initializer

    init() {
        self.bands = [Float](repeating: 0, count: Self.bandCount)
        self.decibels = [Float](repeating: SpectrumAnalyzer.floorDB, count: Self.bandCount)
    }

    // MARK: - Methods. Public

    nonisolated func process(_ buffer: AVAudioPCMBuffer) {
        self.analyzer.enqueue(buffer) { [weak self] result in
            Task { @MainActor [weak self] in
                self?.publish(decibels: result)
            }
        }
    }

    func reset() {
        self.analyzer.reset()
        self.isPlaybackActive = false
        self.isHolding = false
        self.holdGeneration += 1
        self.ignoreQuietUntil = .distantPast
        self.resetPublishedValues()
    }

    func setPlaybackActive(_ isActive: Bool) {
        self.isPlaybackActive = isActive

        if isActive.isFalse {
            // Keep the last RTA frame on screen. Only drop the PCM leftover
            // so resume doesn't mix stale samples into the next FFT.
            self.analyzer.resetInputBuffers()
        }
    }

    func holdUpdates() {
        self.holdGeneration += 1
        self.isHolding = true
    }

    func resumeUpdates() {
        self.holdGeneration += 1
        self.isHolding = false
        self.ignoreQuietUntil = Date().addingTimeInterval(0.15)
    }

    func holdUpdatesTemporarily(for seconds: TimeInterval) {
        self.holdGeneration += 1
        let generation = self.holdGeneration
        self.isHolding = true

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, generation == self.holdGeneration else { return }
            self.isHolding = false
            self.ignoreQuietUntil = Date().addingTimeInterval(0.15)
        }
    }

    // MARK: - Properties. Private

    private static let bandCount = SpectrumAnalyzer.bandCount
    private static let bandCenters = SpectrumAnalyzer.thirdOctaveCenters

    private let analyzer = SpectrumAnalyzer()
    private var isPlaybackActive = false
    private var isHolding = false
    private var holdGeneration = 0
    private var ignoreQuietUntil = Date.distantPast

    // MARK: - Methods. Private

    private func publish(decibels values: [Float]) {
        guard self.isPlaybackActive, self.isHolding.isFalse, values.count == Self.bandCount else {
            return
        }

        let maximum = values.max() ?? SpectrumAnalyzer.floorDB
        if maximum <= SpectrumAnalyzer.floorDB + 1, Date() < self.ignoreQuietUntil {
            return
        }

        self.decibels = values
        self.bands = values.map { Self.normalized(decibels: $0) }
    }

    private func resetPublishedValues() {
        self.decibels = [Float](repeating: SpectrumAnalyzer.floorDB, count: Self.bandCount)
        self.bands = [Float](repeating: 0, count: Self.bandCount)
    }

    private static func normalized(decibels: Float) -> Float {
        let span = SpectrumAnalyzer.ceilingDB - SpectrumAnalyzer.floorDB
        let value = (decibels - SpectrumAnalyzer.floorDB) / span
        return min(1, max(0, value))
    }
}
