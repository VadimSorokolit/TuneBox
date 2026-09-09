//
//  EqualizerServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 09.09.2026.
//

import Foundation
import AVFoundation

@MainActor
protocol EqualizerServicing: AnyObject {
    var bands: [Float] { get }
    var bandCount: Int { get }
    var bandCenters: [Float] { get }
    nonisolated var hopSize: AVAudioFrameCount { get }

    nonisolated func process(_ buffer: AVAudioPCMBuffer)
    func reset()
    func setPlaybackActive(_ isActive: Bool)
    func holdUpdates()
    func resumeUpdates()
    func holdUpdatesTemporarily(for seconds: TimeInterval)
}
