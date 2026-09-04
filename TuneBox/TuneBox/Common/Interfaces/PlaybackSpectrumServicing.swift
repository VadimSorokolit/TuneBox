//
//  PlaybackSpectrumServicinged.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 03.09.2026.
//

import Foundation
import SFBAudioEngine

@MainActor
protocol PlaybackSpectrumServicing: AnyObject {
    static var bandCount: Int { get }
    static var bandCenters: [Float] { get }
    var bands: [Float] { get }
    var decibels: [Float] { get }

    func attach(to player: AudioPlayer, allowRetry: Bool)
    func detach(from player: AudioPlayer)
    func setPlaybackActive(_ isActive: Bool)
    func holdUpdates()
    func resumeUpdates()
    func holdUpdatesTemporarily(for seconds: TimeInterval)
}
