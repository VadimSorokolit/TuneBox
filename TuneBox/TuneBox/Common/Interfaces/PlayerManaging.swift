//
//  PlayerManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 26.05.2026.
//

import Foundation

protocol PlayerManaging: AnyObject, Sendable {
    var track: TrackEntity? { get }
    var playlist: PlaylistEntity? { get }
    var repeatMode: RepeatMode { get }
    var progress: Double { get }
    var isShuffleEnabled: Bool { get }
    var isPlaying: Bool { get }

    func handlePlayAction(for track: TrackEntity, in queue: [TrackEntity])
    func resetPlayback()
    func isPlaying(_ track: TrackEntity) -> Bool
    func seek(by deltaSeconds: TimeInterval)
    func playNext()
    func playPrevious()
    func loadPlaylist()
    func setRepeatMode(_ mode: RepeatMode)
    func toggleShuffle()
}
