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
            Text(
                "\(tracks.count) "
                + "\(tracks.count == 1 ? "track" : "tracks") · "
                + "\(viewModel.tracksDuration(tracks).formattedDuration) · "
                + "\(viewModel.tracksSize(tracks).formattedFileSize)"
            )
            .padding(.top, 10)
            .multilineTextAlignment(.center)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.gray)
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
        return onlyAPI ? all.filter { $0.source == .api } : all
    }
}
