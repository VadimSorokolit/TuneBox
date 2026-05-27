//
//  AudioServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation
import Combine

enum AudioFileExtension: String {
    case mp3
    case wav
    case m4a
}

protocol AudioServicing: AnyObject {
    var currentTrackId: String? { get }
    var duration: TimeInterval { get }
    var currentTime: TimeInterval { get }
    var volume: Float { get set }
    var stateChangeSubject: CurrentValueSubject<Bool, Never> { get }
    var progressSubject: PassthroughSubject<Double, Never> { get }

    func play(trackId: String, url: URL, loop: Bool)
    func pause()
    func resume()
    func stop()
    func toggle(trackId: String, url: URL, loop: Bool)
    func seek(by deltaSeconds: TimeInterval)
    func seek(to progress: Double)
}
