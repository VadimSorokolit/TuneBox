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
    var initialSegment: LibrarySegment?

    // MARK: - Main Body

    var body: some View {
        if let artist {
            Group {
                if artist.albums.isEmpty {
                    ScrollView {
                        TracksContentView(
                            coordinator: coordinator,
                            importManagingVM: importManagingVM,
                            playerVM: playerVM,
                            tracks: artist.tracks
                        )
                    }
                    .scrollToCurrentTrackOnAppear(
                        id: playerVM.track?.id,
                        in: artist.tracks,
                        trigger: artist.id
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
                        artist: artist,
                        initialSegment: initialSegment ?? .albums
                    )
                }
            }
            .customNavigationTitle(artist.name)
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
        let initialSegment: LibrarySegment

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
                .scrollToCurrentTrackOnAppear(
                    id: selected == .tracks ? playerVM.track?.id : nil,
                    in: artist.tracks,
                    trigger: selected
                )
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

        @State private var selected: LibrarySegment
        @State private var direction: SlideDirection = .forward

        // MARK: - Initializer

        init(
            coordinator: AppCoordinator,
            rootTabsVM: RootTabsManaging,
            importManagingVM: ImportManaging,
            playerVM: PlayerManaging,
            artist: MusicLibrary.Artist,
            initialSegment: LibrarySegment
        ) {
            self.coordinator = coordinator
            self.rootTabsVM = rootTabsVM
            self.importManagingVM = importManagingVM
            self.playerVM = playerVM
            self.artist = artist
            self.initialSegment = initialSegment
            _selected = State(initialValue: initialSegment)
        }
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
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    let row = tracks.playbackRow(at: index, currentTrack: playerVM.track)

                    TrackCoverCell(
                        track: track,
                        isPlaying: row.isPlaying,
                        hidesSeparator: row.hidesSeparator,
                        onTapGesture: {
                            playerVM.handlePlayAction(
                                for: track,
                                in: tracks,
                                navigationPath: coordinator.path
                            )
                        }
                    )
                    .id(track.id)
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
