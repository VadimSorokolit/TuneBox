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
        if let library = viewModel.library, library.playlists.isNotEmpty {
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
                        unitSingular: String(LibraryItem.playlists.rawValue.dropLast()),
                        unitPlural: LibraryItem.playlists.rawValue.capitalized,
                        duration: viewModel.tracksDuration(library.playlists.flatMap(\.tracks)),
                        size: viewModel.tracksSize(library.playlists.flatMap(\.tracks)),
                        topPadding: 10
                    )
                }
            }
            .navigationTitle(LibraryItem.playlists.rawValue.capitalized)
            .bottomContentMargin(isPlayerVisible: playerViewModel.isPlayerVisible)
        } else {
            LibraryEmptyStateView(
                item: LibraryItem.playlists,
                prefixText: "Your",
                suffixText: "will appear here.",
                capitalizeItemText: false
            )
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var viewModel: ImportManaging
    @Injected private var playerViewModel: PlayerManaging
}
