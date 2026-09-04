//
//  PlaybackSpectrumService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.09.2026.
//

import Foundation
import Accelerate
import SFBAudioEngine
import Observation

@MainActor
@Observable
final class PlaybackSpectrumService: PlaybackSpectrumServicing {

    // MARK: - Properties. Public

    static let bandCount = SpectrumAnalyzer.bandCount
    static let bandCenters = SpectrumAnalyzer.thirdOctaveCenters

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

    func attach(to player: AudioPlayer, allowRetry: Bool = true) {
        self.detach(from: player)
        self.isPlaybackActive = true

        let analyzer = self.analyzer
        let installed = self.tap.install(
            on: player,
            bufferSize: AVAudioFrameCount(SpectrumAnalyzer.hopSize)
        ) { buffer in
            analyzer.enqueue(buffer) { result in
                Task { @MainActor [weak self] in
                    self?.publish(decibels: result)
                }
            }
        }

        if installed.isFalse, allowRetry {
            DispatchQueue.main.async { [weak self] in
                self?.attach(to: player, allowRetry: false)
            }
        }
    }

    func detach(from player: AudioPlayer) {
        self.tap.remove(from: player)
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

    func holdUpdatesTemporarily(for seconds: TimeInterval = 0.3) {
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

    private let tap = PlaybackPCMMonitor()
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

// MARK: - SpectrumAnalyzer

private final class SpectrumAnalyzer: SpectrumAnalyzing, @unchecked Sendable {

    static let fftSize = 8192
    static let hopSize = 2048
    static let bandCount = thirdOctaveCenters.count
    static let floorDB: Float = -60
    static let ceilingDB: Float = 0

    /// ISO 266 1/3-octave centres, 40 Hz … 16 kHz.
    static let thirdOctaveCenters: [Float] = [
        40, 50, 63, 80, 100, 125, 160, 200, 250,
        315, 400, 500, 630, 800, 1_000, 1_250, 1_600, 2_000,
        2_500, 3_150, 4_000, 5_000, 6_300, 8_000, 10_000, 12_500, 16_000
    ]

    func enqueue(_ buffer: AVAudioPCMBuffer, onResult: @escaping ([Float]) -> Void) {
        let frames = Self.channelFrames(from: buffer)
        guard frames.left.isEmpty.isFalse else { return }

        let rate = Float(buffer.format.sampleRate)
        let stereo = frames.right != nil

        self.queue.async { [weak self] in
            guard let self else { return }

            self.lock.lock()
            self.sampleRate = rate
            self.leftoverLeft.append(contentsOf: frames.left)
            if let right = frames.right {
                self.leftoverRight.append(contentsOf: right)
            }
            self.trim(&self.leftoverLeft)
            self.trim(&self.leftoverRight)

            var latest: [Float]?
            while self.leftoverLeft.count >= Self.fftSize {
                let left = Array(self.leftoverLeft.prefix(Self.fftSize))
                self.leftoverLeft.removeFirst(min(Self.hopSize, self.leftoverLeft.count))

                var right: [Float]?
                if stereo, self.leftoverRight.count >= Self.fftSize {
                    right = Array(self.leftoverRight.prefix(Self.fftSize))
                    self.leftoverRight.removeFirst(min(Self.hopSize, self.leftoverRight.count))
                }

                self.lock.unlock()
                latest = self.analyze(left: left, right: right)
                self.lock.lock()
            }
            self.lock.unlock()

            if let latest {
                onResult(latest)
            }
        }
    }

    func reset() {
        self.lock.lock()
        self.leftoverLeft.removeAll(keepingCapacity: true)
        self.leftoverRight.removeAll(keepingCapacity: true)
        self.envelopeDB = [Float](repeating: Self.floorDB, count: Self.bandCount)
        self.lock.unlock()
    }

    func resetInputBuffers() {
        self.lock.lock()
        self.leftoverLeft.removeAll(keepingCapacity: true)
        self.leftoverRight.removeAll(keepingCapacity: true)
        self.lock.unlock()
    }

    // MARK: - Initializer

    init() {
        self.envelopeDB = [Float](repeating: Self.floorDB, count: Self.bandCount)
    }

    // MARK: - Deinitializer

    deinit {
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    // MARK: - Properties. Private

    /// Attack / release as time constants so ballistics stay the same
    /// at 44.1 / 48 / 96 kHz. ≈ 35 ms up, 220 ms down.
    private let attackTime: Float = 0.035
    private let releaseTime: Float = 0.220
    private let queue = DispatchQueue(label: "tunebox.spectrum.fft", qos: .userInteractive)
    private let lock = NSLock()
    private var fftSetup: FFTSetup?
    private var window: [Float] = []
    private var windowed: [Float] = []
    private var realp: [Float] = []
    private var imagp: [Float] = []
    private var leftPower: [Float] = []
    private var rightPower: [Float] = []
    private var leftoverLeft: [Float] = []
    private var leftoverRight: [Float] = []
    private var envelopeDB: [Float]
    private var sampleRate: Float = 44_100
    private var log2n = vDSP_Length(log2(Float(fftSize)))

    // MARK: - Methods. Private

    private func trim(_ samples: inout [Float]) {
        let maxCount = Self.fftSize + Self.hopSize
        guard samples.count > maxCount else { return }
        samples.removeFirst(samples.count - maxCount)
    }

    private func analyze(left: [Float], right: [Float]?) -> [Float] {
        self.prepareIfNeeded()

        guard left.count >= Self.fftSize, self.fftSetup != nil else {
            return [Float](repeating: Self.floorDB, count: Self.bandCount)
        }

        self.fillPowerSpectrum(from: left, into: &self.leftPower)

        if let right, right.count >= Self.fftSize {
            self.fillPowerSpectrum(from: right, into: &self.rightPower)
            var half: Float = 0.5
            vDSP_vasm(
                self.leftPower,
                1,
                self.rightPower,
                1,
                &half,
                &self.leftPower,
                1,
                vDSP_Length(self.leftPower.count)
            )
        }

        return self.thirdOctaveBands(from: self.leftPower)
    }

    private func prepareIfNeeded() {
        if self.fftSetup == nil {
            self.log2n = vDSP_Length(log2(Float(Self.fftSize)))
            self.fftSetup = vDSP_create_fftsetup(self.log2n, FFTRadix(kFFTRadix2))
        }

        let halfN = Self.fftSize / 2
        guard self.window.count != Self.fftSize else { return }

        var hann = [Float](repeating: 0, count: Self.fftSize)
        vDSP_hann_window(&hann, vDSP_Length(Self.fftSize), Int32(vDSP_HANN_NORM))
        self.window = hann
        self.windowed = [Float](repeating: 0, count: Self.fftSize)
        self.realp = [Float](repeating: 0, count: halfN)
        self.imagp = [Float](repeating: 0, count: halfN)
        self.leftPower = [Float](repeating: 0, count: halfN)
        self.rightPower = [Float](repeating: 0, count: halfN)
    }

    private func fillPowerSpectrum(from samples: [Float], into power: inout [Float]) {
        let halfN = Self.fftSize / 2
        vDSP_vmul(samples, 1, self.window, 1, &self.windowed, 1, vDSP_Length(Self.fftSize))

        self.realp.withUnsafeMutableBufferPointer { realBuffer in
            self.imagp.withUnsafeMutableBufferPointer { imagBuffer in
                var split = DSPSplitComplex(
                    realp: realBuffer.baseAddress!,
                    imagp: imagBuffer.baseAddress!
                )

                self.windowed.withUnsafeBytes { rawBuffer in
                    let complexBuffer = rawBuffer.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(
                        complexBuffer.baseAddress!,
                        2,
                        &split,
                        1,
                        vDSP_Length(halfN)
                    )
                }

                vDSP_fft_zrip(
                    self.fftSetup!,
                    &split,
                    1,
                    self.log2n,
                    FFTDirection(FFT_FORWARD)
                )

                var scale = 1 / Float(Self.fftSize * 2)
                vDSP_vsmul(
                    realBuffer.baseAddress!,
                    1,
                    &scale,
                    realBuffer.baseAddress!,
                    1,
                    vDSP_Length(halfN)
                )
                vDSP_vsmul(
                    imagBuffer.baseAddress!,
                    1,
                    &scale,
                    imagBuffer.baseAddress!,
                    1,
                    vDSP_Length(halfN)
                )
                vDSP_zvmags(&split, 1, &power, 1, vDSP_Length(halfN))
            }
        }

        power[0] = 0
    }

    private func thirdOctaveBands(from power: [Float]) -> [Float] {
        let binHz = self.sampleRate / Float(Self.fftSize)
        let nyquist = self.sampleRate / 2
        let halfBandwidthRatio = pow(2 as Float, 1 / 6)
        var result = [Float](repeating: Self.floorDB, count: Self.bandCount)
        let deltaTime = Float(Self.hopSize) / max(self.sampleRate, 1)

        for (index, center) in Self.thirdOctaveCenters.enumerated() {
            guard center < nyquist else { continue }

            let energy = Self.integratedPower(
                power,
                fromHz: center / halfBandwidthRatio,
                toHz: min(nyquist, center * halfBandwidthRatio),
                binHz: binHz
            )
            let decibels = Self.powerToDecibels(energy)
            let previous = self.envelopeDB[index]
            let coefficient = decibels > previous
                ? Self.ballisticCoefficient(timeConstant: self.attackTime, deltaTime: deltaTime)
                : Self.ballisticCoefficient(timeConstant: self.releaseTime, deltaTime: deltaTime)
            let smoothed = previous + (decibels - previous) * coefficient
            let clamped = min(Self.ceilingDB, max(Self.floorDB, smoothed))
            self.envelopeDB[index] = clamped
            result[index] = clamped
        }

        return result
    }

    private static func ballisticCoefficient(timeConstant: Float, deltaTime: Float) -> Float {
        guard timeConstant > 0 else { return 1 }
        return 1 - exp(-deltaTime / timeConstant)
    }

    private static func powerToDecibels(_ power: Float) -> Float {
        guard power > 0 else { return Self.floorDB }

        let decibels = 10 * log10(power)
        guard decibels.isFinite else { return Self.floorDB }

        return min(Self.ceilingDB, max(Self.floorDB, decibels))
    }

    private static func integratedPower(
        _ power: [Float],
        fromHz: Float,
        toHz: Float,
        binHz: Float
    ) -> Float {
        let start = max(fromHz / binHz, 1)
        let end = min(toHz / binHz, Float(power.count - 1))
        guard end > start else { return 0 }

        let firstBin = Int(floor(start))
        let lastBin = min(power.count - 1, Int(ceil(end)))
        guard firstBin <= lastBin else { return 0 }

        var energy: Float = 0
        for bin in firstBin ... lastBin {
            let overlap = min(Float(bin + 1), end) - max(Float(bin), start)
            if overlap > 0 {
                energy += power[bin] * overlap
            }
        }

        return energy
    }

    private static func channelFrames(
        from buffer: AVAudioPCMBuffer
    ) -> (left: [Float], right: [Float]?) {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0, let channels = buffer.floatChannelData else {
            return ([], nil)
        }

        let left = Array(UnsafeBufferPointer(start: channels[0], count: frameCount))
        guard buffer.format.channelCount >= 2 else {
            return (left, nil)
        }

        let right = Array(UnsafeBufferPointer(start: channels[1], count: frameCount))

        return (left, right)
    }
}
