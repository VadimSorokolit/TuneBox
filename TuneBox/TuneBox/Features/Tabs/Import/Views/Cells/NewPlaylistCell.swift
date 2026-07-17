//
//  NewPlaylistCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 17.07.2026.
//

import SwiftUI

struct NewPlaylistCell: View {

    // MARK: - Properties. Public

    let playlist: PlaylistEntity
    let onTapGesture: () -> Void

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 24, weight: .medium))
                        .frame(size: 24)

                    VStack(spacing: 0) {
                        Text("\(playlist.title)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                                .font(.system(size: 12, weight: .medium))

                        Text("\(playlist.tracks.count) \(playlist.tracks.count == 1 ? "track" : "tracks")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .font(.system(size: 10, weight: .regular))
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
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onTapGesture {
            onTapGesture()
        }
    }
}

#Preview {
    NewPlaylistCell(
        playlist: PlaylistEntity(
            title: "Favorites",
            tracks: []
        ),
        onTapGesture: {}
    )
}
