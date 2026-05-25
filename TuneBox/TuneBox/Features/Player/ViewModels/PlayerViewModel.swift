//
//  PlayerViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation
import Observation

protocol PlayerManaging: AnyObject {
    func handlePlayAction(for track: TrackEntity)
    func isPlaying(_ track: TrackEntity) -> Bool
}

@Observable
final class PlayerViewModel: PlayerManaging {

    // MARK: - Initializer

    init() {
        self.audioService.onStateChange = { [weak self] isPlaying in
            self?.isPlaying = isPlaying
        }
    }

    // MARK: - Methods. Public

    func handlePlayAction(for track: TrackEntity) {
        self.playingTrackID = track.id
        self.audioService.toggle(trackId: track.id)
    }

    func isPlaying(_ track: TrackEntity) -> Bool {
        self.playingTrackID == track.id && self.isPlaying
    }

    // MARK: - Properties. Private
    
    private let audioService = AudioService.shared
    private var isPlaying = false
    private var playingTrackID: String?
}
