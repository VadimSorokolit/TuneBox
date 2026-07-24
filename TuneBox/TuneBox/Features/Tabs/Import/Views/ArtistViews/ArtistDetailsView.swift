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
            if artist.albums.isEmpty {
                TracksContentView(
                    viewModel: viewModel,
                    tracks: artist.tracks
                )
            } else {
                ChipsView(
                    viewModel: viewModel,
                    artist: artist
                )
            }
        } else {
            ContentUnavailableView(
                "Artist not found",
                systemImage: "person.crop.circle.badge.exclamationmark",
                description: Text("The selected artist is unavailable")
            )
        }
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: ImportManaging

    // MARK: - Private. Objects

    private struct ChipsView: View {

        // MARK: - Propeties. Public

        let viewModel: ImportManaging
        let artist: MusicLibrary.Artist

        // MARK: - Body

        var body: some View {
            VStack(spacing: 20) {
                SegmentedControl(
                    selected: $selected,
                    direction: $direction,
                    items: LibrarySegment.allCases
                )

                ZStack {
                    switch selected {
                        case .albums:
                            AlbumsContentView(
                                viewModel: viewModel,
                                albums: artist.albums
                            )
                            .id(selected)
                            .segmentTransition(direction)

                        case .tracks:
                            TracksContentView(
                                viewModel: viewModel,
                                tracks: artist.tracks
                            )
                            .id(selected)
                            .segmentTransition(direction)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: selected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 26)
            .padding(.horizontal, 26)
        }

        // MARK: - Properties. Private

        @State private var selected: LibrarySegment = .albums
        @State private var direction: SlideDirection = .forward
    }

    private struct AlbumsContentView: View {

        // MARK: - Properties. Public

        let viewModel: ImportManaging
        let albums: [MusicLibrary.Album]

        // MARK: - Body

        var body: some View {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(albums) { album in
                        AlbumCell(
                            album: album,
                            onTapGesture: {
                                coorditaor.push(.album(album))
                            }
                        )
                    }

                    LibrarySummaryFooter(
                        count: albums.count,
                        unitSingular: "album",
                        unitPlural: "albums",
                        duration: viewModel.tracksDuration(albums.flatMap(\.tracks)),
                        size: viewModel.tracksSize(albums.flatMap(\.tracks))
                    )
                }
            }
        }

        // MARK: - Properties. Private

        @Environment(AppCoordinator.self) private var coorditaor
    }

    private struct TracksContentView: View {

        // MARK: - Properties. Public

        let viewModel: ImportManaging
        let tracks: [TrackEntity]

        // MARK: - Body

        var body: some View {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        NewTrackCell(index: index + 1,
                                     track: track,
                                     isPlaying: false,
                                     onTapGesture: {}
                        )
                    }
                }

                LibrarySummaryFooter(
                    count: tracks.count,
                    unitSingular: "track",
                    unitPlural: "tracks",
                    duration: viewModel.tracksDuration(tracks),
                    size: viewModel.tracksSize(tracks)
                )
            }
        }

        // MARK: - Properties. Private

        @Environment(AppCoordinator.self) private var coorditaor
    }
}
