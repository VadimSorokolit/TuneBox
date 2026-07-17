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
                VStack(spacing: 10) {
                    ArtworkView(artworkPath: album.cover,
                                size: 300,
                                cornerRadius: 5
                    )

                    LazyVStack(spacing: 0) {
                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                            NewTrackCell(index: index + 1,
                                         track: track,
                                         isPlaying: false,
                                         onTapGesture: {}
                            )
                        }
                    }

                    Text(
                        "\(album.tracks.count) "
                        + "\(album.tracks.count == 1 ? "track" : "tracks") · "
                        + "\(viewModel.tracksDuration(album.tracks).formattedDuration) · "
                        + "\(viewModel.tracksSize(album.tracks).formattedFileSize)"
                    )
                    .padding(.top, 10)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.gray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentMargins(.bottom, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: album.artist.isEmpty ? 0 : 2) {
                        if album.artist.isNotEmpty {
                            Text(album.artist)
                                .lineLimit(1)
                                .font(.caption)
                        }

                        Text(album.name)
                            .lineLimit(album.artist.isEmpty ? 2 : 1)
                            .font(.headline)
                    }
                    .frame(width: 200, alignment: .center)
                }
            }
        }
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: ImportManaging
}
