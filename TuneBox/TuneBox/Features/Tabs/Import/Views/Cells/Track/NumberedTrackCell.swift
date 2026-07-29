//
//  NumberedTrackCell.swift
//  TuneBox
//
//  Created by Vadiy Sorokolit on 15.07.2026.
//

import SwiftUI

struct NumberedTrackCell: View {

    // MARK: - Properties. Public

    let index: Int
    let track: TrackEntity
    let isPlaying: Bool
    let onTapGesture: () -> Void

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 12) {
                    Circle()
                        .stroke(.gray.opacity(0.8), lineWidth: 1.5)
                        .frame(size: 20)
                        .overlay {
                            Text("\(index)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.gray)
                        }

                    Text("\(track.songName)")
                        .lineLimit(4)
                        .font(.system(size: 18, weight: .regular))
                }

                Spacer()

                Text(track.formattedDuration)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 26)

            Rectangle()
                .fill(.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.leading, 65)
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
    NumberedTrackCell(
        index: 12,
        track: TrackEntity(
            id: "1",
            image: nil,
            songName: "Believer Believer Believer Believer Believer Believer Believer Believer Believer Believer Believer Believer",
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
