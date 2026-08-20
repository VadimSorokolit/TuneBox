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
    var playbackNavigationPath: [AppRoute] { get }
    var repeatMode: RepeatMode { get }
    var progress: Double { get }
    var sourceFormatText: String { get }
    var outputRouteText: String { get }
    var isPlaying: Bool { get }
    var isShuffleEnabled: Bool { get }
    var isPlayerVisible: Bool { get }
    var shouldLoadCover: Bool { get }

    func handlePlayAction(for track: TrackEntity, in queue: [TrackEntity], navigationPath: [AppRoute]?)
    func togglePlayPause()
    func restoreLastPlaybackSession()
    func persistPlaybackSession()
    func refreshPlaybackNavigationPath(library: MusicLibrary?)
    func resetPlayback()
    func stopAudioPreservingSession()
    func clearPlaybackIfAffected(byRemovedSourceID sourceID: UUID, isAPISource: Bool)
    func isPlaying(_ track: TrackEntity) -> Bool
    func seek(by deltaSeconds: TimeInterval)
    func setSeekScrubbing(_ isScrubbing: Bool)
    func playNext()
    func playPrevious()
    func loadPlaylist()
    func setRepeatMode(_ mode: RepeatMode)
    func toggleShuffle()
}
