//
//  PlaylistsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

struct PlaylistsView: View {

    // MARK: - Main Body

    var body: some View {
        if let library = viewModel.library {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(library.playlists) { playlist in
                        NewPlaylistCell(
                            playlist: playlist,
                            onTapGesture: {
                                coordinator.push(.playlist(playlist))
                            }
                        )
                    }

                    Text(
                        "\(library.playlists.count) "
                        + "\(library.playlists.count == 1 ? "playlist" : "playlist") · "
                        + "\(viewModel.tracksDuration(library.playlists.flatMap(\.tracks)).formattedDuration) · "
                        + "\(viewModel.tracksSize(library.playlists.flatMap(\.tracks)).formattedFileSize)"
                    )
                    .padding(.top, 10)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.gray)
                }
            }
            .navigationTitle("Playlists")
            .padding(.top, 10)
            .contentMargins(.bottom, 26)
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var viewModel: ImportManaging
}
