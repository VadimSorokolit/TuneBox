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
                                index: index + 1,
                                track: track,
                                onTapGesture: {
                                    playerViewModel.handlePlayAction(
                                        for: track,
                                        in: album.tracks,
                                        origin: .album(album)
                                    )
                                }
                            )
                        }

                        LibrarySummaryFooter(
                            count: album.tracks.count,
                            unitSingular: "track",
                            unitPlural: "tracks",
                            duration: viewModel.tracksDuration(album.tracks),
                            size: viewModel.tracksSize(album.tracks),
                            topPadding: 10
                        )
                    }

                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .bottomContentMargin(isPlayerVisible: playerViewModel.track != nil)
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

    @Injected private var viewModel: ImportManaging
    @Injected private var playerViewModel: PlayerManaging
}
