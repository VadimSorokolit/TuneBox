//
//  TracksView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

struct TracksView: View {

    // MARK: - Properties. Public

    var onlyAPI: Bool = false

    // MARK: - Main Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    NewTrackCell(
                        index: index + 1,
                        track: track,
                        isPlaying: false,
                        onTapGesture: {}
                    )
                }
            }

            LibrarySummaryFooter(
                count: tracks.count,
                unitSingular: "track",
                unitPlural: "tracks",
                duration: viewModel.tracksDuration(tracks),
                size: viewModel.tracksSize(tracks)
            )
        }
        .navigationTitle("Tracks")
        .padding(.top, 16)
        .contentMargins(.bottom, 16)
        .onAppear {
            Task {
                viewModel.startObservingTracksChanges()
                await viewModel.refreshLibrary()
            }
        }
        .onDisappear {
            viewModel.stopObservingTracksChanges()
        }
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: ImportManaging

    private var tracks: [TrackEntity] {
        let all = viewModel.library?.tracks ?? []
        let filtered = onlyAPI
            ? all.filter { $0.source == .api }
            : all

        var seen = Set<DeduplicationKey>()

        return filtered.filter { track in
            seen.insert(
                DeduplicationKey(
                    songName: track.songName,
                    artistName: track.artistName
                )
            ).inserted
        }
    }

    // MARK: - Private. Objects

    private struct DeduplicationKey: Hashable {
        let songName: String
        let artistName: String
    }
}
