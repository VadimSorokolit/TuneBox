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
                        NewTrackCell(index: index + 1,
                                     track: track,
                                     isPlaying: false,
                                     onTapGesture: {}
                        )
                    }
                }

                Text(
                    "\(playlist.tracks.count) "
                    + "\(playlist.tracks.count == 1 ? "track" : "tracks") · "
                    + "\(viewModel.tracksDuration(playlist.tracks).formattedDuration) · "
                    + "\(viewModel.tracksSize(playlist.tracks).formattedFileSize)"
                )
                .padding(.top, 10)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.gray)
            }
            .padding(.top, 16)
            .contentMargins(.bottom, 24)
        }
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: TestManaging
}
