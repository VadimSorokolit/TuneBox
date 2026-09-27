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
        Group {
            if let library = importManagingVM.library, library.playlists.isNotEmpty {
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
                            unitSingular: L10n.Library.unitPlaylist,
                            unitPlural: L10n.Library.unitPlaylists,
                            duration: importManagingVM.tracksDuration(library.playlists.flatMap(\.tracks)),
                            size: importManagingVM.tracksSize(library.playlists.flatMap(\.tracks))
                        )
                    }
                }
                .bottomContentMargin(
                    10,
                    0,
                    isPlayerVisible: playerVM.isPlayerVisible,
                    isPlaying: playerVM.isPlaying,
                    isTabBarVisible: rootTabsVM.isTabBarVisible
                )
            } else {
                LibraryEmptyStateView(
                    item: LibraryItem.playlists,
                    prefixText: L10n.Library.emptyPlaylistsPrefix,
                    suffixText: L10n.Library.emptyPlaylistsSuffix,
                    capitalizeItemText: false
                )
            }
        }
        .libraryMenuNavigationTitle(LibraryItem.playlists.localizedTitle)
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var rootTabsVM: RootTabsManaging
    @Injected private var importManagingVM: ImportManaging
    @Injected private var playerVM: PlayerManaging
}
