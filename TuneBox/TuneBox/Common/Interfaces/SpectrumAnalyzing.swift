//
//  SpectrumAnalyzing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 03.09.2026.
//

import Foundation
import AVFoundation

nonisolated protocol SpectrumAnalyzing: AnyObject, Sendable {
    func enqueue(
        _ buffer: AVAudioPCMBuffer,
        generation: UInt64,
        onResult: @escaping ([Float]) -> Void
    )
    func reset(accepting generation: UInt64)
    func resetInputBuffers()
    func seedEnvelope(_ values: [Float])
}
