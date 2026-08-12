//
//  TrackArtworkCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 24.07.2026.
//

import SwiftUI

struct TrackCoverCell: View {

    // MARK: - Properties. Public

    let track: TrackEntity
    let verticalPadding: CGFloat = 8
    let defaultPadding: CGFloat = GlobalConstants.Cell.defaultPadding
    let onTapGesture: () -> Void

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: verticalPadding) {
            HStack {
                HStack(spacing: 10) {
                    CoverView(
                        coverPath: track.imagePath,
                        size: GlobalConstants.Cell.imageSize,
                        cornerRadius: GlobalConstants.Cell.imageCornerRadius
                    )

                    VStack(alignment: .leading, spacing: track.artistName.isNotEmpty ? 4 : 0) {
                        Text("\(track.songName)")
                            .lineLimit(GlobalConstants.Cell.textLineLimit)
                            .font(GlobalConstants.Cell.titleFont)

                        if track.artistName.isNotEmpty {
                            Text("\(track.artistName)")
                                .lineLimit(GlobalConstants.Cell.textLineLimit)
                                .font(GlobalConstants.Cell.subtitleFont)
                                .foregroundStyle(.gray)
                        }
                    }
                }

                Spacer()

                Text(track.formattedDuration)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, defaultPadding)

            Rectangle()
                .fill(.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.leading, 82)
                .padding(.trailing, defaultPadding)
        }
        .padding(.top, verticalPadding)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapGesture()
        }
    }
}

#Preview {
    TrackCoverCell(
        track: TrackEntity(
            id: "1",
            image: nil,
            songName: "Believer Believer Believer Believer Believer Believer Believer Believer",
            duration: 200,
            artistName: "Imagine Dragons",
            albumName: "Evolve",
            releaseDate: nil,
            download: nil,
            waveformData: nil,
            size: 5_242_880
        ),
        onTapGesture: {}
    )
}
