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

    @Injected private var viewModel: TestManaging

    // MARK: - Private. Objects

    private struct ChipsView: View {

        // MARK: - Propeties. Public

        let viewModel: TestManaging
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

        let viewModel: TestManaging
        let albums: [MusicLibrary.Album]

        // MARK: - Body

        var body: some View {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(albums) { album in
                        AlbumCell(
                            album: album,
                            onTapGesture: {
                                coorditaor.push(.album(album: album))
                            }
                        )
                    }

                    Text(
                        "\(albums.count) "
                        + "\(albums.count == 1 ? "album" : "albums") · "
                        + "\(viewModel.tracksDuration(albums.flatMap(\.tracks)).formattedDuration) · "
                        + "\(viewModel.tracksSize(albums.flatMap(\.tracks)).formattedFileSize)"
                    )
                    .padding(.top, 20)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.gray)
                }
            }
        }

        // MARK: - Properties. Private

        @Environment(AppCoordinator.self) private var coorditaor
    }

    private struct TracksContentView: View {

        // MARK: - Properties. Public

        let viewModel: TestManaging
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

                Text(
                    "\(tracks.count) "
                    + "\(tracks.count == 1 ? "track" : "tracks") · "
                    + "\(viewModel.tracksDuration(tracks).formattedDuration) · "
                    + "\(viewModel.tracksSize(tracks).formattedFileSize)"
                )
                .padding(.top, 10)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.gray)
            }
        }

        // MARK: - Properties. Private

        @Environment(AppCoordinator.self) private var coorditaor
    }
}
