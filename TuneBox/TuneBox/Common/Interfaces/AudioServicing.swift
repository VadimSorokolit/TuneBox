//
//  Untitled.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation

protocol AudioServicing: AnyObject {
    var currentTrackId: String? { get }
    var isPlaying: Bool { get }
    var duration: TimeInterval { get }
    var currentTime: TimeInterval { get }
    var volume: Float { get set }
    var onStateChange: ((Bool) -> Void)? { get set }
    var onProgress: ((Double) -> Void)? { get set }

    func play(trackId: String, ext: String, loop: Bool)
    func pause()
    func resume()
    func stop()
    func toggle(trackId: String, ext: String, loop: Bool)
    func seek(by deltaSeconds: TimeInterval)
    func seek(to progress: Double)
    func playEffect(name: String, ext: String)
}
