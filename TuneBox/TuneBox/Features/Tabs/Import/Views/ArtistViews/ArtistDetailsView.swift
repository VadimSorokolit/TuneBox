//
//  ArtistDetailsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 16.07.2026.
//

import SwiftUI
import Resolver

enum LibrarySegment: Int, CaseIterable, SegmentedItem {
    case albums
    case tracks

    var title: String {
        switch self {
            case .albums:
                "Albums"
            case .tracks:
                "Tracks"
        }
    }
}

struct ArtistDetailsView: View {

    // MARK: - Properties. Public

    let artist: MusicLibrary.Artist?

    // MARK: - Main Body

    var body: some View {
        if let artist {
            Group {
                if artist.albums.isEmpty {
                    TracksContentView(
                        coordinator: coordinator,
                        importManagingVM: importManagingVM,
                        playerVM: playerVM,
                        tracks: artist.tracks
                    )
                    .bottomContentMargin(
                        20,
                        isPlayerVisible: playerVM.isPlayerVisible,
                        isTabBarVisible: rootTabsVM.isTabBarVisible
                    )
                } else {
                    ChipsView(
                        coordinator: coordinator,
                        rootTabsVM: rootTabsVM,
                        importManagingVM: importManagingVM,
                        playerVM: playerVM,
                        artist: artist
                    )
                }
            }
            .navigationTitle(artist.name)
        } else {
            ContentUnavailableView(
                "Artist not found",
                systemImage: "person.crop.circle.badge.exclamationmark",
                description: Text("The selected artist is unavailable")
            )
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var rootTabsVM: RootTabsManaging
    @Injected private var importManagingVM: ImportManaging
    @Injected private var playerVM: PlayerManaging

    // MARK: - Private. Objects

    private struct ChipsView: View {

        // MARK: - Properties. Public

        let coordinator: AppCoordinator
        let rootTabsVM: RootTabsManaging
        let importManagingVM: ImportManaging
        let playerVM: PlayerManaging
        let artist: MusicLibrary.Artist

        // MARK: - Body

        var body: some View {
            VStack(spacing: 10) {
                SegmentedControl(
                    selected: $selected,
                    direction: $direction,
                    items: LibrarySegment.allCases
                )
                .padding(.horizontal, 10)

                ScrollView {
                    ZStack {
                        switch selected {
                            case .albums:
                                AlbumsContentView(
                                    coorditaor: coordinator,
                                    importManagingVM: importManagingVM,
                                    playerVM: playerVM,
                                    albums: artist.albums
                                )
                                .id(selected)
                                .segmentTransition(direction)

                            case .tracks:
                                TracksContentView(
                                    coordinator: coordinator,
                                    importManagingVM: importManagingVM,
                                    playerVM: playerVM,
                                    tracks: importManagingVM.sortedTracksAlphabetically(artist.tracks),
                                )
                                .id(selected)
                                .segmentTransition(direction)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: selected)
                }
                .bottomContentMargin(
                    10,
                    0,
                    isPlayerVisible: playerVM.isPlayerVisible,
                    isTabBarVisible: rootTabsVM.isTabBarVisible
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 16)
        }

        // MARK: - Properties. Private

        @State private var selected: LibrarySegment = .albums
        @State private var direction: SlideDirection = .forward
    }

    private struct AlbumsContentView: View {

        // MARK: - Properties. Public

        let coorditaor: AppCoordinator
        let importManagingVM: ImportManaging
        let playerVM: PlayerManaging
        let albums: [MusicLibrary.Album]

        // MARK: - Body

        var body: some View {
            LazyVStack(spacing: 0) {
                ForEach(albums) { album in
                    AlbumCell(
                        album: album,
                        displayContext: .artist,
                        onTapGesture: {
                            coorditaor.push(.album(album))
                        }
                    )
                }

                LibrarySummaryFooter(
                    count: albums.count,
                    unitSingular: "album",
                    unitPlural: "albums",
                    duration: importManagingVM.tracksDuration(albums.flatMap(\.tracks)),
                    size: importManagingVM.tracksSize(albums.flatMap(\.tracks))
                )
            }
        }
    }

    private struct TracksContentView: View {

        // MARK: - Properties. Public

        let coordinator: AppCoordinator
        let importManagingVM: ImportManaging
        let playerVM: PlayerManaging
        let tracks: [TrackEntity]

        // MARK: - Body

        var body: some View {
            LazyVStack(spacing: 0) {
                ForEach(tracks) { track in
                    TrackCoverCell(
                        track: track,
                        onTapGesture: {
                            playerVM.handlePlayAction(
                                for: track,
                                in: tracks,
                                navigationPath: coordinator.path
                            )
                        }
                    )
                }

                LibrarySummaryFooter(
                    count: tracks.count,
                    unitSingular: "track",
                    unitPlural: "tracks",
                    duration: importManagingVM.tracksDuration(tracks),
                    size: importManagingVM.tracksSize(tracks)
                )
            }
        }

        // MARK: - Properties. Private

        @Environment(AppCoordinator.self) private var coorditaor
    }
}
