//
//  TracksView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

struct TracksView: View {

    // MARK: - Main Body

    var body: some View {
        if let library = viewModel.library {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(library.tracks.enumerated()), id: \.element.id) { index, track in
                        NewTrackCell(index: index + 1,
                                     track: track,
                                     isPlaying: false,
                                     onTapGesture: {}
                        )
                    }
                }

                Text(
                    "\(library.tracks.count) "
                    + "\(library.tracks.count == 1 ? "track" : "tracks") · "
                    + "\(viewModel.tracksDuration(library.tracks).formattedDuration) · "
                    + "\(viewModel.tracksSize(library.tracks).formattedFileSize)"
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
