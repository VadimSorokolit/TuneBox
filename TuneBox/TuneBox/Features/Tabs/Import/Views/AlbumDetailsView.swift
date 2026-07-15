//
//  AlbumTracksView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI

struct AlbumDetailsView: View {
    let album: MusicLibrary.Album?

    var body: some View {
        if let album {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ArtworkView(artworkPath: album.cover,
                                size: 300,
                                cornerRadius: 5
                    )

                    ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                        NewTrackCell(index: index + 1,
                                     track: track,
                                     isPlaying: false,
                                     onTapGesture: {}
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentMargins(.bottom, 80)
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
}
