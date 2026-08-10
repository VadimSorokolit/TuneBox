//
//  AlbumTracksView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

struct AlbumDetailsView: View {

    // MARK: - Properties. Public

    let album: MusicLibrary.Album?

    // MARK: - Main Body

    var body: some View {
        if let album {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    ArtworkView(artworkPath: album.cover,
                                size: 300,
                                cornerRadius: 5
                    )

                    LazyVStack(spacing: 0) {
                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                            NumberedTrackCell(
                                index: track.trackNumber ?? index + 1,
                                track: track,
                                onTapGesture: {
                                    playerVM.handlePlayAction(
                                        for: track,
                                        in: album.tracks,
                                        navigationPath: coordinator.path
                                    )
                                }
                            )
                        }

                        LibrarySummaryFooter(
                            count: album.tracks.count,
                            unitSingular: "track",
                            unitPlural: "tracks",
                            duration: importManagingVM.tracksDuration(album.tracks),
                            size: importManagingVM.tracksSize(album.tracks),
                            topPadding: 10
                        )
                    }

                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .bottomContentMargin(
                10,
                0,
                isPlayerVisible: playerVM.isPlayerVisible,
                isTabBarVisible: rootTabsVM.isTabBarVisible
            )
            .contentMargins(.top, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: album.artist.isEmpty ? 0 : 2) {
                        Text(album.name)
                            .lineLimit(album.artist.isEmpty ? 2 : 1)
                            .font(.headline)

                        if album.artist.isNotEmpty {
                            Text(album.artist)
                                .lineLimit(1)
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var rootTabsVM: RootTabsManaging
    @Injected private var importManagingVM: ImportManaging
    @Injected private var playerVM: PlayerManaging
}
