//
//  PlaybackPCMMonitoring.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.09.2026.
//

import Foundation
import SFBAudioEngine

protocol PlaybackPCMMonitoring: AnyObject {
    @discardableResult
    func install(
        on player: AudioPlayer,
        bufferSize: AVAudioFrameCount,
        handler: @escaping (AVAudioPCMBuffer) -> Void
    ) -> Bool

    func remove(from player: AudioPlayer)
}
