//
//  DownloadsViewModel.swift
//  TuneBox
//
//  Created by Nintendo on 14.06.2026.
//

import Foundation
import Observation
import Resolver

enum RecentTracksLimit: Int, CaseIterable {
    case all = 0
    case twenty = 20
    case fifty = 50
    case hundred = 100
}

@MainActor
class DownloadsViewModel: DownloadsPresenting {

    // MARK: - Properties. Public

    private(set) var sections: [TracksSection] = []

    // MARK: - Methods. Public

    func fetchTracksSection() {
        Task {
            if self.isAllTracksLimit {
                let tracks = await self.transferViewModel.getAllPersistedTracks()

                let activeTracks = tracks.filter {
                    [.downloading, .queued, .paused].contains($0.downloadState)
                }

                let downloadedTracks = tracks.filter {
                    $0.downloadState == .completed
                }

                self.set(activeTracks, for: .activeDownloads)
                self.set(downloadedTracks, for: .downloaded)
            } else {
                async let activeTracks = self.transferViewModel.getRecentActiveTracks(limit: self.tracksLimit)
                async let downloadedTracks = self.transferViewModel.getRecentDownloadedTracks(limit: self.tracksLimit)

                let (active, downloaded) = await (activeTracks, downloadedTracks)

                self.set(active, for: .activeDownloads)
                self.set(downloaded, for: .downloaded)
            }
        }
    }

    func setTracksLimit(_ limit: RecentTracksLimit) {
        self.tracksLimit = limit.rawValue
    }

    // MARK: - Properties. Private

    @Injected
    private var transferViewModel: TransferManaging

    private var tracksLimit: Int = RecentTracksLimit.all.rawValue

    private var isAllTracksLimit: Bool {
        self.tracksLimit == RecentTracksLimit.all.rawValue
    }

    // MARK: - Methods. Private

    private func set(
        _ tracks: [TrackEntity],
        for type: TracksSection.SectionType
    ) {
        if let index = self.sections.firstIndex(where: { $0.type == type }) {
            self.sections[index].tracks = tracks
        } else {
            self.sections.append(
                TracksSection(
                    type: type,
                    tracks: tracks
                )
            )
        }
    }
}
