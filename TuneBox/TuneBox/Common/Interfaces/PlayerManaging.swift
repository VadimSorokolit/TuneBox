//
//  PlayerManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 26.05.2026.
//

import Foundation

protocol PlayerManaging: AnyObject, Sendable {
    var playlist: PlaylistEntity? { get }
    var progress: Double { get }

    func handlePlayAction(for track: TrackEntity)
    func resetPlayback()
    func isPlaying(_ track: TrackEntity) -> Bool
    func playNext()
    func playPrevious()
    func loadPlaylist()
}
