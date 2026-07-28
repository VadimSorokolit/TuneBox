//
//  AlbumCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI

struct AlbumCell: View {

    // MARK: - Properties. Public

    let album: MusicLibrary.Album
    let onTapGesture: () -> Void

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                HStack(spacing: 10) {
                    ArtworkView(
                        artworkPath: album.cover,
                        size: 46,
                        cornerRadius: 8
                    )

                    VStack(spacing: album.artist.isEmpty ? 0 : 4) {
                        Text("\(album.name)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(album.artist.isEmpty ? 2 : 1)
                            .font(.system(size: 16, weight: .medium))

                        if let date = album.date, date.isNotEmpty {
                            Text("\(date)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                                .font(.system(size: 10, weight: .regular))
                        }
                    }
                    .padding(.trailing, 26)
                }
                .padding(.leading, 26)
            }

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.leading, 82)
                .padding(.trailing, 26)
        }
        .padding(.top, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onTapGesture {
            onTapGesture()
        }
    }
}

#Preview {
    AlbumCell(
        album: MusicLibrary.Album(
            id: "1",
            name: "Random Access Memories",
            artist: "Daft Punk",
            date: "2026",
            tracks: [],
            cover: nil
        ),
        onTapGesture: {}
    )
}
