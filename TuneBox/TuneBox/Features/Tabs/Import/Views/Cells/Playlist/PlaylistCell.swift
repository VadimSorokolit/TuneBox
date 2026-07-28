//
//  NewPlaylistCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 17.07.2026.
//

import SwiftUI

struct PlaylistCell: View {

    // MARK: - Properties. Public

    let playlist: PlaylistEntity
    let onTapGesture: () -> Void

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.gray)
                        .font(.system(size: GlobalConstants.Cell.imageSize, weight: .medium))
                        .frame(size: GlobalConstants.Cell.imageSize)
                        .overlay {
                            RoundedRectangle(cornerRadius: GlobalConstants.Cell.imageCornerRadius)
                                .stroke(.clear, lineWidth: 1)
                        }

                    VStack(spacing: 2) {
                        if playlist.title.isNotEmpty {
                            Text("\(playlist.title)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(GlobalConstants.Cell.textLineLimit)
                                .font(GlobalConstants.Cell.titleFont)
                                .foregroundStyle(.black.opacity(0.8))
                        }

                        Text("\(playlist.tracks.count) \(playlist.tracks.count == 1 ? "track" : "tracks")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(GlobalConstants.Cell.textLineLimit)
                            .font(GlobalConstants.Cell.subtitleFont)
                            .foregroundStyle(.gray)
                    }
                    .padding(.trailing, 26)
                }
                .padding(.leading, 26)
            }

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.leading, 60)
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
    PlaylistCell(
        playlist: PlaylistEntity(
            title: "Favorites",
            tracks: []
        ),
        onTapGesture: {}
    )
}
