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
        if let library = importManagingVM.library {
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
                                duration: importManagingVM.tracksDuration(library.albums.flatMap(\.tracks)),
                                size: importManagingVM.tracksSize(library.albums.flatMap(\.tracks))
                            )
                        }
                    }
                    .bottomContentMargin(
                        10,
                        0,
                        isPlayerVisible: playerVM.isPlayerVisible,
                        isTabBarVisible: rootTabsVM.isTabBarVisible
                    )
                } else {
                    LibraryEmptyStateView(item: LibraryItem.albums)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(LibraryItem.albums.rawValue.capitalized)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var rootTabsVM: RootTabsManaging
    @Injected private var importManagingVM: ImportManaging
    @Injected private var playerVM: PlayerManaging
}
