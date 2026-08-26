//
//  ArtistsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

struct ArtistsView: View {

    // MARK: - Main Body

    var body: some View {
        if let library = importManagingVM.library, library.artists.isNotEmpty {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(library.artists) { artist in
                        ArtistCell(
                            artist: artist,
                            onTapGesture: {
                                coordinator.push(.artist(artist))
                            }
                        )
                    }

                    LibrarySummaryFooter(
                        count: library.artists.count,
                        unitSingular: String(LibraryItem.artists.rawValue.dropLast()),
                        unitPlural: LibraryItem.artists.rawValue,
                        duration: importManagingVM.tracksDuration(library.artists.flatMap(\.tracks)),
                        size: importManagingVM.tracksSize(library.artists.flatMap(\.tracks))
                    )
                }
            }
            .navigationTitle(LibraryItem.artists.rawValue.capitalized)
            .bottomContentMargin(
                10,
                0,
                isPlayerVisible: playerVM.isPlayerVisible,
                isTabBarVisible: rootTabsVM.isTabBarVisible
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            LibraryEmptyStateView(item: LibraryItem.artists)
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var rootTabsVM: RootTabsManaging
    @Injected var importManagingVM: ImportManaging
    @Injected private var playerVM: PlayerManaging
}
