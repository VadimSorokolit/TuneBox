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
        VStack(spacing: 5) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: LibraryItem.artists.systemImage)
                        .foregroundStyle(.gray)
                        .font(.system(size: GlobalConstants.Cell.imageSize, weight: .medium))
                        .frame(size: GlobalConstants.Cell.imageSize)
                        .overlay {
                            RoundedRectangle(cornerRadius: GlobalConstants.Cell.imageCornerRadius)
                                .stroke(.gray, lineWidth: 1)
                                .frame(size: GlobalConstants.Cell.imageSize)
                        }

                    Text(artist.name)
                        .font(GlobalConstants.Cell.titleFont)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 26)

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.leading, 82)
                .padding(.trailing, 26)
        }
        .padding(.top, 5)
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
