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
        guard self.processGate.isEnabled else { return }

        let generation = self.processGate.generation
        self.analyzer.enqueue(buffer) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, generation == self.processGate.generation else { return }
                self.publish(decibels: result)
            }
        }
    }

    nonisolated func stopProcessing() {
        self.processGate.invalidate()
        self.analyzer.resetInputBuffers()
    }

    func reset() {
        self.processGate.invalidate()
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
            self.didReportDropout = false
            self.setProcessEnabled(false)
            self.analyzer.resetInputBuffers()
            return
        }

        self.didReportDropout = false

        self.analyzer.seedEnvelope(self.decibels)
        self.analyzer.resetInputBuffers()
        if self.isHolding.isFalse {
            self.setProcessEnabled(true)
        }
    }

    func holdUpdates() {
        self.holdGeneration += 1
        self.isHolding = true
        self.setProcessEnabled(false)
    }

    func resumeUpdates() {
        self.holdGeneration += 1
        self.isHolding = false
        self.analyzer.seedEnvelope(self.decibels)
        self.analyzer.resetInputBuffers()
        self.setProcessEnabled(true)
        self.ignoreQuietUntil = Date().addingTimeInterval(0.15)
    }

    func holdUpdatesTemporarily(for seconds: TimeInterval) {
        self.holdGeneration += 1
        let generation = self.holdGeneration
        self.isHolding = true
        self.setProcessEnabled(false)

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, generation == self.holdGeneration else { return }
            self.isHolding = false
            self.analyzer.seedEnvelope(self.decibels)
            self.analyzer.resetInputBuffers()
            self.setProcessEnabled(true)
            self.ignoreQuietUntil = Date().addingTimeInterval(0.15)
        }
    }

    // MARK: - Properties. Private

    private static let bandCount = SpectrumAnalyzer.bandCount
    private static let bandCenters = SpectrumAnalyzer.thirdOctaveCenters

    private let analyzer = SpectrumAnalyzer()
    nonisolated private let processGate = SpectrumProcessGate()
    private var isPlaybackActive = false
    private var isHolding = false
    private var holdGeneration = 0
    private var ignoreQuietUntil = Date.distantPast
    private var didReportDropout = false

    // MARK: - Methods. Private

    private func publish(decibels values: [Float]) {
        guard self.processGate.isEnabled else { return }
        guard self.isPlaybackActive, self.isHolding.isFalse, values.count == Self.bandCount else {
            return
        }

        let maximum = values.max() ?? SpectrumAnalyzer.floorDB
        if maximum <= SpectrumAnalyzer.floorDB + 1, Date() < self.ignoreQuietUntil {
            return
        }

        let previousMaximum = self.decibels.max() ?? SpectrumAnalyzer.floorDB
        let droppedOut = previousMaximum > SpectrumAnalyzer.floorDB + 8
            && previousMaximum - maximum >= 8
            && zip(self.decibels, values).allSatisfy { $1 <= $0 + 0.5 }

        if droppedOut {
            self.processGate.invalidate()
            self.analyzer.resetInputBuffers()

            if self.didReportDropout.isFalse {
                self.didReportDropout = true
                NotificationCenter.default.post(name: .playbackOutputDropoutDetected, object: nil)
            }

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

    private func setProcessEnabled(_ enabled: Bool) {
        self.processGate.setEnabled(enabled)
    }
}

nonisolated private final class SpectrumProcessGate: @unchecked Sendable {

    nonisolated var isEnabled: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.isEnabledFlag
    }

    nonisolated var generation: UInt64 {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.generationValue
    }

    nonisolated func setEnabled(_ enabled: Bool) {
        self.lock.lock()
        self.isEnabledFlag = enabled
        self.lock.unlock()
    }

    nonisolated func invalidate() {
        self.lock.lock()
        self.isEnabledFlag = false
        self.generationValue += 1
        self.lock.unlock()
    }

    private let lock = NSLock()
    private var isEnabledFlag = true
    private var generationValue: UInt64 = 0
}
