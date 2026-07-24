//
//  PlaylistDetailsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 17.07.2026.
//

import SwiftUI
import Resolver

struct PlaylistDetailsView: View {

    // MARK: - Properties. Private

    let playlist: PlaylistEntity?

    // MARK: - Main Body

    var body: some View {
        if let playlist {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                        NumberedTrackCell(index: index + 1,
                                     track: track,
                                     isPlaying: false,
                                     onTapGesture: {}
                        )
                    }
                }

                LibrarySummaryFooter(
                    count: playlist.tracks.count,
                    unitSingular: "track",
                    unitPlural: "tracks",
                    duration: viewModel.tracksDuration(playlist.tracks),
                    size: viewModel.tracksSize(playlist.tracks)
                )
            }
            .padding(.top, 16)
            .contentMargins(.bottom, 24)
        }
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: ImportManaging
}
