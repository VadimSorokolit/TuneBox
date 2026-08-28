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
        if let album = currentAlbum {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    ZStack {
                        if isVinylVisible,
                           let track = playerVM.track {
                            SpinningVinylView(
                                track: track,
                                isPlaying: playerVM.isPlaying,
                                isLoading: coverVM.isLoading,
                                isSeekScrubbing: playerVM.isSeekScrubbing,
                                isTapSpinning: playerVM.isVinylTapSpinning,
                                progress: playerVM.progress,
                                revolutionDuration: playerVM.vinylRevolutionDuration,
                                spinDirection: playerVM.vinylSpinDirection,
                                spinSpeed: playerVM.vinylSpinSpeed,
                                vinylSize: maximumSize,
                                coverSize: minimumSize,
                                holeSize: centerHoleSize,
                                onTap: {
                                    coordinator.push(.covers(album))
                                }
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.88)))
                        } else {
                            CoverView(
                                coverPath: album.cover,
                                size: maximumSize,
                                cornerRadius: 5,
                                onTap: {
                                    coordinator.push(.covers(album))
                                }
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.88)))
                        }
                    }
                    .frame(size: maximumSize)
                    .animation(.easeInOut(duration: 0.35), value: isVinylVisible)

                    LazyVStack(spacing: 0) {
                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                            NumberedTrackCell(
                                index: track.trackNumber ?? index + 1,
                                track: track,
                                isPlaying: track === playerVM.track,
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
                            size: importManagingVM.tracksSize(album.tracks)
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
                    VStack(spacing: 2) {
                        Text(album.name)
                            .font(.headline)
                            .lineLimit(1)

                        Text(album.artist)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .multilineTextAlignment(.center)
                    .frame(width: 250)
                }
            }
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var rootTabsVM: RootTabsManaging
    @Injected private var importManagingVM: ImportManaging
    @Injected private var playerVM: PlayerManaging
    @Injected private var coverVM: CoverManaging

    private let minimumSize: CGFloat = 106
    private let maximumSize: CGFloat = 300
    private let centerHoleSize: CGFloat = 10

    private var isVinylVisible: Bool {
        guard let track = playerVM.track else {
            return false
        }

        return album?.tracks.contains { $0.id == track.id } ?? false
    }

    private var currentAlbum: MusicLibrary.Album? {
        guard let album else { return nil }
        return importManagingVM.library?.albums.first { $0.id == album.id } ?? album
    }
}

#Preview {
    NavigationStack {
        AlbumDetailsView(
            album: MusicLibrary.Album(
                id: "1",
                name: "Random Access Memories",
                artist: "Daft Punk",
                date: "2013",
                tracks: [
                    TrackEntity(
                        id: "1",
                        image: nil,
                        songName: "Give Life Back to Music",
                        duration: 274,
                        artistName: "Daft Punk",
                        albumName: "Random Access Memories",
                        releaseDate: "2013",
                        download: nil,
                        waveformData: nil,
                        size: 5_242_880,
                        trackNumber: 1
                    ),
                    TrackEntity(
                        id: "2",
                        image: nil,
                        songName: "Get Lucky",
                        duration: 369,
                        artistName: "Daft Punk",
                        albumName: "Random Access Memories",
                        releaseDate: "2013",
                        download: nil,
                        waveformData: nil,
                        size: 5_242_880,
                        trackNumber: 3
                    )
                ],
                cover: nil
            )
        )
        .environment(AppCoordinator(root: .main))
    }
}
