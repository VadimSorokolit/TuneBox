//
//  AlbumsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

struct AlbumsView: View {

    // MARK: - Main Body

    var body: some View {
        if let library = viewModel.library {
            Group {
                if library.albums.isNotEmpty {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(library.albums) { album in
                                AlbumCell(
                                    album: album,
                                    displayContext: .album,
                                    onTapGesture: {
                                        coordinator.push(.album(album))
                                    }
                                )
                            }

                            LibrarySummaryFooter(
                                count: library.albums.count,
                                unitSingular: String(LibraryItem.albums.rawValue.dropLast()),
                                unitPlural: LibraryItem.albums.rawValue,
                                duration: viewModel.tracksDuration(library.albums.flatMap(\.tracks)),
                                size: viewModel.tracksSize(library.albums.flatMap(\.tracks)),
                                topPadding: 10
                            )
                        }
                    }
                    .bottomContentMargin(isPlayerVisible: playerViewModel.track != nil)
                } else {
                    LibraryEmptyStateView(item: LibraryItem.albums)
                }
            }
            .navigationTitle(LibraryItem.albums.rawValue.capitalized)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: ImportManaging
    @Injected private var playerViewModel: PlayerManaging
    @Environment(AppCoordinator.self) private var coordinator
}
