//
//  Untitled.swift
//  TuneBox
//
//  Created by Nintendo on 14.06.2026.
//

import Foundation
import Observation
import Resolver

class DownloadsViewModel: DownloadsPresenting {
    @Injected private var transferViewModel: TransferManaging

    private(set) var sections: [TracksSection] = []

    func fetchTracksSection() {
        let tracks = self.transferViewModel.sections.flatMap(\.tracks)

        let activeTracks = tracks.filter {
            [.downloading, .queued, .paused]
                .contains($0.downloadState)
        }

        let downloadedTracks = tracks.filter {
            $0.downloadState == .completed
        }

        self.sections = [
            TracksSection(
                type: .activeDownloads,
                tracks: activeTracks
            ),
            TracksSection(
                type: .downloaded,
                tracks: downloadedTracks
            )
        ]
    }
}
