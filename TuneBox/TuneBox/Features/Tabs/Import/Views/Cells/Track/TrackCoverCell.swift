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
    let isPlaying: Bool
    let hidesSeparator: Bool
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
                        size: GlobalConstants.TrackCell.imageSize,
                        cornerRadius: GlobalConstants.TrackCell.imageCornerRadius
                    )

                    VStack(
                        alignment: .leading,
                        spacing: track.artistName.isNotEmpty
                        ? 4
                        : 0
                    ) {
                        Text("\(track.songName)")
                            .lineLimit(GlobalConstants.Cell.textLineLimit)
                            .font(
                                .satoshi.semiBold.size(
                                    GlobalConstants.TrackCell.primaryTextSize,
                                    for: track.songName,
                                    .medium
                                )
                            )

                        if track.artistName.isNotEmpty {
                            Text("\(track.artistName)")
                                .lineLimit(GlobalConstants.Cell.textLineLimit)
                                .font(
                                    .satoshi.medium.size(
                                        GlobalConstants.TrackCell.secondaryTextSize,
                                        for: track.artistName,
                                        .medium
                                    )
                                )
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Text(track.formattedDuration)
                    .font(.jetBrainsMono.regular.size(GlobalConstants.TrackCell.durationTextSize))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, defaultPadding)

            Rectangle()
                .fill(hidesSeparator
                      ? .gray.opacity(0)
                      : .gray.opacity(0.2)
                )
                .frame(height: 1)
                .padding(.leading, 82)
                .padding(.trailing, defaultPadding)
        }
        .padding(.top, verticalPadding)
        .frame(maxWidth: .infinity)
        .backgroundPlayingCell(isPlaying: isPlaying)
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
        isPlaying: true,
        hidesSeparator: true,
        onTapGesture: {}
    )
}
