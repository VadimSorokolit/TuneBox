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
    private(set) var selectedTracksType: TracksType = .active
    private(set) var completedSearchQuery = ""
    private(set) var isSearchLoading = false

    // MARK: - Methods. Public

    func fetchTracksSectionBy(_ type: TracksType) async {
        self.selectedTracksType = type

        async let recentTracks = self.transferViewModel.getRecentTracks(limit: self.tracksLimit)
        async let allTracks: [TrackEntity] = {
            switch type {
                case .downloaded:
                    return await self.transferViewModel.getRecentDownloadedTracks(limit: nil)

                case .active:
                    return await self.transferViewModel.getRecentActiveTracks(limit: nil)
            }
        }()

        // Concurrency execution
        let (recent, all) = await (recentTracks, allTracks)

        if recent.isEmpty.isFalse
            || all.isEmpty.isFalse {
            self.sections.removeAll()
        }

        self.set(recent, for: .recent)
        self.set(all, for: .all)
    }

    func loadSearchBy(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        
        guard trimmedQuery.count > 2 else {
            isSearchLoading = false
            return
        }
        
        isSearchLoading = true
        defer { isSearchLoading = false }

        var seen = Set<String>()

        let tracks = sections
            .filter { $0.type != .search }
            .flatMap(\.tracks)

        let filtered = tracks.filter { track in
            let matches =
                track.songName.localizedStandardContains(query)
                || track.albumName.localizedStandardContains(query)

            guard matches else { return false }

            let key = "\(track.songName.lowercased())|\(track.artistName.lowercased())"

            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        self.completedSearchQuery = trimmedQuery
        self.set(filtered, for: .search)
    }

    func setTracksLimit(_ limit: RecentTracksLimit) {
        self.tracksLimit = limit.rawValue
    }

    func setType(_ type: TracksType) {
        self.selectedTracksType = type
    }

    func handleDownloadAction(for track: TrackEntity) async {
        await self.transferViewModel.handleDownloadAction(for: track)
    }

    func startObservingTracksChanges() {
        self.transferViewModel.onTracksChanged = { [weak self] in
            guard let self else { return }

            Task {
                await self.fetchTracksSectionBy(self.selectedTracksType)
            }
        }
    }

    func clearSearchState() {
        self.isSearchLoading = false
        self.completedSearchQuery = ""
        self.set([], for: .search)
    }

    // MARK: - Properties. Private

    @Injected
    @ObservationIgnored
    private var transferViewModel: TransferManaging

    private var tracksLimit: Int = RecentTracksLimit.small.rawValue

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
