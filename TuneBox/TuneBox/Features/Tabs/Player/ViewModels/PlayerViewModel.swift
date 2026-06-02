//
//  PlayerViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation
import Combine

@Observable
final class PlayerViewModel: PlayerManaging {

    // MARK: - Initializer

    init() {
        self.audioService.stateChangeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Methods. Public

    func handlePlayAction(for track: TrackEntity) {
        do {
            let url = try FileManagerService.makeDownloadedTrackURL(id: track.id)

            self.track = track
            self.audioService.toggle(trackId: track.id, url: url, loop: false)
        } catch {
            AppLogger.audio.error("Failed to make track URL: \(String(describing: error))")
        }
    }

    func isPlaying(_ track: TrackEntity) -> Bool {
        self.track?.id == track.id && self.isPlaying
    }

    // MARK: - Properties. Private

    private let audioService = AudioService.shared
    private var isPlaying = false
    private var track: TrackEntity?
    private var cancellables = Set<AnyCancellable>()
}
