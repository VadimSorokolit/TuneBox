//
//  AudioServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation
import Combine

enum PlaylistExtension: String {
    case m3u
    case m3u8
}

enum AudioFileExtension: String {
    case mp3
    case wav
    case flac
    // swiftlint:disable:next identifier_name
    case wv
    case dsf
    case dff
    case m4a
    case aac
    case aiff
    case aif
    case caf
    case ape
    case ogg
    case opus
    case mpc
    case tta
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
    func setNowPlaying(track: TrackEntity)
    func seek(by deltaSeconds: TimeInterval)
    func seek(to progress: Double)
}
