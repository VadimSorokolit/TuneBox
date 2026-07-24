//
//  ImportedPlaylistCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.07.2026.
//

import SwiftUI

struct ImportedPlaylistCell: View {
    let playlist: ImportedPlaylist
    let isSelected: Bool
    let onCellTap: () -> Void

    var body: some View {
        Button(
            action: {
                onCellTap()
            }, label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(playlist.title)
                            .font(.headline)

                        Text("\(playlist.trackURLs.count) tracks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                    } else {
                        Image(systemName: "circle")
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.gray.opacity(0.5))
                )
            }
        )
    }
}

#Preview {
    ImportedPlaylistCell(
        playlist: ImportedPlaylist(
            title: "Rock Classics",
            fileURL: URL(fileURLWithPath: "/Users/test/Rock.m3u"),
            trackURLs: [
                URL(fileURLWithPath: "/Users/test/song1.mp3"),
                URL(fileURLWithPath: "/Users/test/song2.mp3"),
                URL(fileURLWithPath: "/Users/test/song3.mp3")
            ]
        ),
        isSelected: true,
        onCellTap: {}
    )
    .padding()
}
