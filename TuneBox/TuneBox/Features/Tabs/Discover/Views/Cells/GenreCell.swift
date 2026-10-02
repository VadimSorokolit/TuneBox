//
//  GenreCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 05.06.2026.
//

import SwiftUI
import SDWebImageSwiftUI

struct GenreCellConfiguration {
    var cornerRadius: CGFloat = 10
    var imageCornerRadius: CGFloat = 10
    var imageAspectRatio: CGFloat = 1.0
    var spacing: CGFloat = 8
    var padding: CGFloat = 8
    var showDuration: Bool = true
    var showDownloadButton: Bool = true
    var titleLineLimit: Int = 2
    var subtitleLineLimit: Int = 2
    var showSubtitle: Bool = true
}

struct GenreCell: View {
    let track: TrackEntity
    let onButtonTap: () -> Void
    var configuration: GenreCellConfiguration = .init()

    private enum Constants {
        static let textLineHeight: CGFloat = 20
        static let textBlockSpacing: CGFloat = 2
    }

    private var imageSide: CGFloat {
        GlobalConstants.GenreCell.width - configuration.padding * 2
    }

    /// Fixed slot for title + subtitle so covers/bottom stay aligned.
    /// Short title lets subtitle sit higher inside the same block.
    private var textBlockHeight: CGFloat {
        let titleHeight = Constants.textLineHeight * CGFloat(configuration.titleLineLimit)
        guard configuration.showSubtitle else { return titleHeight }
        let subtitleHeight = Constants.textLineHeight * CGFloat(configuration.subtitleLineLimit)
        return titleHeight + Constants.textBlockSpacing + subtitleHeight
    }

    var body: some View {
        ZStack {
            EmptyGenreCell()

            VStack(alignment: .leading, spacing: configuration.spacing) {
                trackImage
                    .frame(width: imageSide, height: imageSide)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: configuration.imageCornerRadius))

                VStack(alignment: .leading, spacing: Constants.textBlockSpacing) {
                    Text(track.songName)
                        .font(.satoshi.medium.size(GlobalConstants.TrackCell.primaryTextSize))
                        .foregroundStyle(.primary)
                        .lineLimit(configuration.titleLineLimit)
                        .multilineTextAlignment(.leading)

                    if configuration.showSubtitle {
                        Text(track.albumName)
                            .font(.satoshi.medium.size(GlobalConstants.TrackCell.primaryTextSize))
                            .foregroundStyle(.secondary)
                            .lineLimit(configuration.subtitleLineLimit)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: textBlockHeight,
                    maxHeight: textBlockHeight,
                    alignment: .topLeading
                )

                Spacer(minLength: 0)

                if configuration.showDuration
                    || configuration.showDownloadButton {
                    bottomRow
                }
            }
            .padding(configuration.padding)
        }
        .frame(
            width: GlobalConstants.GenreCell.width,
            height: GlobalConstants.GenreCell.height,
            alignment: .top
        )
    }

    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: configuration.cornerRadius)
            .fill(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
    }

    private var bottomRow: some View {
        HStack {
            if configuration.showDuration {
                Text(track.formattedDuration)
                    .font(.jetBrainsMono.regular.size(GlobalConstants.TrackCell.durationTextSize))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if configuration.showDownloadButton {
                TrackDownloadButton(
                    track: track,
                    action: onButtonTap
                )
            }
        }
    }

    @ViewBuilder
    private var trackImage: some View {
        if let url = track.imageURL {
            WebImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: "music.note")
            .resizable()
            .scaledToFit()
            .padding(16)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
    }
}

#Preview {
    GenreCell(
        track: makePreviewTrack(),
        onButtonTap: {}
    )
    .frame(width: 150, height: 280)
    .padding()
}

private func makePreviewTrack() -> TrackEntity {
    let track = TrackEntity(
        id: "1",
        image: "https://usercontent.jamendo.com/?type=album&id=24&width=300&trackid=168",
        songName: "Believer Believer Believer Believer Believer Believer",
        duration: 200,
        artistName: "Imagine Dragons Imagine Dragons Imagine Dragons Imagine Dragons Imagine Dragons",
        albumName: "Evolve Evolve Evolve",
        releaseDate: "2017-02-01",
        download: nil,
        waveformData: nil,
        size: 5_242_880
    )

    track.downloadState = .downloading

    return track
}
