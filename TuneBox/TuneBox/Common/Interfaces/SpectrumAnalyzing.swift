//
//  SpectrumAnalyzing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 03.09.2026.
//

import Foundation
import SFBAudioEngine

protocol SpectrumAnalyzing: AnyObject, Sendable {
    func enqueue(
        _ buffer: AVAudioPCMBuffer,
        onResult: @escaping ([Float]) -> Void
    )
    func reset()
    func resetInputBuffers()
}
