//
//  WaveformService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 30.07.2026.
//

import SFBAudioEngine

final class WaveformService: WaveformServicing {

    // MARK: - Methods. Public

    static func makeWaveform(from url: URL, targetPeaks: Int = 64) -> Waveform? {
        guard let decoder = try? AudioDecoder(url: url) else { return nil }

        do {
            try decoder.open()
        } catch {
            return nil
        }
        defer { try? decoder.close() }

        let format = decoder.processingFormat
        let totalFrames = decoder.length
        guard totalFrames > 0 else { return nil }

        let framesPerPeak = max(Int(totalFrames) / targetPeaks, 1)
        let chunkFrames = AVAudioFrameCount(min(framesPerPeak, 4096))

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: chunkFrames
        ) else { return nil }

        var peaks = Array(repeating: 0, count: targetPeaks)
        var peakIndex = 0
        var framesInCurrentPeak = 0
        var maxAmp: Float = 0

        while peakIndex < targetPeaks {
            do {
                try decoder.decode(into: buffer, length: chunkFrames)
            } catch {
                break
            }

            let decoded = Int(buffer.frameLength)
            if decoded == 0 { break }

            guard let samples = buffer.floatChannelData?[0] else { break }

            for index in 0 ..< decoded {
                maxAmp = max(maxAmp, abs(samples[index]))
                framesInCurrentPeak += 1

                if framesInCurrentPeak >= framesPerPeak {
                    peaks[peakIndex] = Int((maxAmp * 100).rounded())
                    peakIndex += 1
                    framesInCurrentPeak = 0
                    maxAmp = 0
                    if peakIndex >= targetPeaks { break }
                }
            }
        }

        if peakIndex < targetPeaks, framesInCurrentPeak > 0 {
            peaks[peakIndex] = Int((maxAmp * 100).rounded())
        }

        return Waveform(peaks: peaks)
    }
}
