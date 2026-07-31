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
        if let library = viewModel.library, library.artists.isNotEmpty {
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
                        duration: viewModel.tracksDuration(library.artists.flatMap(\.tracks)),
                        size: viewModel.tracksSize(library.artists.flatMap(\.tracks)),
                        topPadding: 10
                    )
                }
            }
            .navigationTitle(LibraryItem.artists.rawValue.capitalized)
            .bottomContentMargin(isPlayerVisible: playerViewModel.track != nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            LibraryEmptyStateView(item: LibraryItem.artists)
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected var viewModel: ImportManaging
    @Injected private var playerViewModel: PlayerManaging
}
