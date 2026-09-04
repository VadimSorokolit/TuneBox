//
//  SFBAudioTap.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.09.2026.
//

import Foundation
import AVFoundation
import SFBAudioEngine

/// Monitors PCM audio from the SFB player's main mixer.
/// Uses `modifyProcessingGraph` and `mainMixerNode.installTap`
/// to receive the rendered playback audio..
final class PlaybackPCMMonitor: PlaybackPCMMonitoring, @unchecked Sendable {

    // MARK: - Methods. Public

    @discardableResult
    func install(
        on player: AudioPlayer,
        bufferSize: AVAudioFrameCount,
        handler: @escaping (AVAudioPCMBuffer) -> Void
    ) -> Bool {
        self.remove(from: player)

        var didInstall = false

        player.modifyProcessingGraph { engine in
            let mixer = engine.mainMixerNode
            let format = mixer.outputFormat(forBus: 0)
            guard format.channelCount > 0, format.sampleRate > 0 else { return }

            mixer.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
                handler(buffer)
            }
            didInstall = true
        }

        self.lock.lock()
        self.isInstalled = didInstall
        self.lock.unlock()

        return didInstall
    }

    func remove(from player: AudioPlayer) {
        self.lock.lock()
        let shouldRemove = self.isInstalled
        self.isInstalled = false
        self.lock.unlock()

        guard shouldRemove else { return }

        player.modifyProcessingGraph { engine in
            engine.mainMixerNode.removeTap(onBus: 0)
        }
    }

    // MARK: - Properties. Private

    private let lock = NSLock()
    private var isInstalled = false
}
