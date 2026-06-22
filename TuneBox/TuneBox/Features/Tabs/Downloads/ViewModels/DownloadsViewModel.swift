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
    case small = 6
    case medium = 12
    case large = 18
}

@MainActor
@Observable
class DownloadsViewModel: DownloadsPresenting {

    // MARK: - Properties. Public

    private(set) var sections: [TracksSection] = []

    // MARK: - Methods. Public

    func fetchTracksSection() async {
        let isDownloaded = self.selectedTracksType == .downloaded
        let tracksLimit = self.tracksLimit

        async let recentTracks = self.transferViewModel.getRecentTracks(limit: tracksLimit)
        async let allTracks: [TrackEntity] = {
            if isDownloaded {
                return await self.transferViewModel.getRecentDownloadedTracks(limit: nil)
            } else {
                return await self.transferViewModel.getRecentActiveTracks(limit: nil)
            }
        }()

        // Concurrency execution
        let (recent, all) = await (recentTracks, allTracks)

        self.set(recent, for: .recent)
        self.set(all, for: .all)
    }

    func setTracksLimit(_ limit: RecentTracksLimit) {
        self.tracksLimit = limit.rawValue
    }

    func set(_ type: TracksType) {
        self.selectedTracksType = type
    }

    func handleDownloadAction(for track: TrackEntity) async {
        await self.transferViewModel.handleDownloadAction(for: track)
    }

    func startObservingTracksChanges() {
        self.transferViewModel.onTracksChanged = { [weak self] in
            Task {
                await self?.fetchTracksSection()
            }
        }
    }

    // MARK: - Properties. Private

    @Injected
    @ObservationIgnored
    private var transferViewModel: TransferManaging

    private var tracksLimit: Int = RecentTracksLimit.small.rawValue
    private var selectedTracksType: TracksType = .active

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
