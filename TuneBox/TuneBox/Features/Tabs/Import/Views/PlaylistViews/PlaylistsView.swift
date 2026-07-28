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
                        PlaylistCell(
                            playlist: playlist,
                            onTapGesture: {
                                coordinator.push(.tracks(playlist.title, .fixed(playlist.tracks)))
                            }
                        )
                    }

                    LibrarySummaryFooter(
                        count: library.playlists.count,
                        unitSingular: "playlist",
                        unitPlural: "playlists",
                        duration: viewModel.tracksDuration(library.playlists.flatMap(\.tracks)),
                        size: viewModel.tracksSize(library.playlists.flatMap(\.tracks)),
                        topPadding: 10
                    )
                }
            }
            .navigationTitle("Playlists")
            .padding(.top, 10)
            .contentMargins(.bottom, 20)
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var viewModel: ImportManaging
}
