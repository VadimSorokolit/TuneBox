//
//  TrackArtworkCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 24.07.2026.
//

import SwiftUI

struct TrackArtworkCell: View {

    // MARK: - Properties. Public

    let track: TrackEntity
    let isPlaying: Bool
    let onTapGesture: () -> Void

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    ArtworkView(
                        artworkPath: track.imagePath,
                        size: 36,
                        cornerRadius: 8
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(track.songName)")
                            .lineLimit(1)
                            .font(.system(size: 20, weight: .regular))

                        Text("\(track.albumName)")
                            .lineLimit(1)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.gray)
                    }
                }

                Spacer()

                Text(track.formattedDuration)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 26)

            Rectangle()
                .fill(.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.leading, 75)
                .padding(.trailing, 26)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
        .onTapGesture {
            onTapGesture()
        }
    }
}

#Preview {
    TrackArtworkCell(
        track: TrackEntity(
            id: "1",
            image: nil,
            songName: "Believer",
            duration: 200,
            artistName: "Imagine Dragons",
            albumName: "Evolve",
            releaseDate: nil,
            download: nil,
            waveformData: nil,
            size: 5_242_880
        ),
        isPlaying: false,
        onTapGesture: {}
    )
}
