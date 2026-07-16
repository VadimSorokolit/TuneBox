//
//  ArtistCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 16.07.2026.
//

import SwiftUI

struct ArtistCell: View {

    // MARK: - Properties. Public

    let artist: MusicLibrary.Artist
    let onTapGesture: () -> Void

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: LibraryItem.artists.systemImage)
                        .foregroundStyle(.gray)
                        .font(.system(size: 22, weight: .medium))
                        .frame(size: 22)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.gray, lineWidth: 1)
                                .frame(size: 30)
                        }

                    Text(artist.name)
                        .font(.system(size: 18, weight: .regular))
                }
                .contentShape(Rectangle())

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 26)

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.leading, 58)
                .padding(.trailing, 26)
        }
        .padding(.top, 15)
        .onTapGesture {
            onTapGesture()
        }
    }
}

#Preview {
    ArtistCell(
        artist: MusicLibrary.Artist(
            id: "1",
            name: "Imagine Dragons",
            tracks: [],
            albums: []
        ),
        onTapGesture: {}
    )
}
