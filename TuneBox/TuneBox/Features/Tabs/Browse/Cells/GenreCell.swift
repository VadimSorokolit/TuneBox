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
        static let width: CGFloat = 110
        static let height: CGFloat = 230
        static let textLineHeight: CGFloat = 17
        static let textBlockSpacing: CGFloat = 2
    }

    private var imageSide: CGFloat {
        Constants.width - configuration.padding * 2
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

                if configuration.showDuration || configuration.showDownloadButton {
                    bottomRow
                }
            }
            .padding(configuration.padding)
        }
        .frame(width: Constants.width, height: Constants.height, alignment: .top)
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
                Button(action: onButtonTap) {
                    downloadButton
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
            }
        }
    }

    private var downloadButton: some View {
        let progress = min(max(track.downloadingProgress, 0), 1)

        return ZStack {
            if track.downloadState != .completed,
               track.downloadState != .idle {
                Circle()
                    .stroke(Color.white, lineWidth: 0.8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.green,
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            stateImage
                .font(.system(size: GlobalConstants.TrackCell.actionButtonIconSize, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(size: GlobalConstants.TrackCell.actionButtonSize)
        }
        .frame(size: GlobalConstants.TrackCell.actionButtonSize)
    }

    private var accessibilityLabel: String {
        switch track.downloadState {
            case .idle:
                L10n.Track.a11yStartDownload

            case .queued:
                L10n.Track.a11yCancelDownload

            case .downloading:
                L10n.Track.a11yPauseDownload

            case .paused:
                L10n.Track.a11yResumeDownload

            case .completed:
                L10n.Track.a11yDelete

            case .failed:
                L10n.Track.a11yRetry
        }
    }

    @ViewBuilder
    private var stateImage: some View {
        switch track.downloadState {
            case .idle:
                Image(systemName: track.fileState == .removed ? "cloud" : "arrow.down")

            case .queued:
                Image(systemName: "clock")

            case .downloading:
                Image(systemName: "pause.fill")

            case .paused:
                Image(systemName: "play.fill")

            case .completed:
                Image(systemName: "trash.fill")

            case .failed:
                Image(systemName: "exclamationmark.circle")
        }
    }

    private var iconColor: Color {
        switch track.downloadState {
            case .idle:
                return .primary
            case .queued:
                return .yellow
            case .downloading:
                return .red
            case .paused:
                return .blue
            case .completed:
                return .red
            case .failed:
                return .orange
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
    .frame(width: 120, height: 180)
    .padding()
}

private func makePreviewTrack() -> TrackEntity {
    let track = TrackEntity(
        id: "1",
        image: "https://usercontent.jamendo.com/?type=album&id=24&width=300&trackid=168",
        songName: "Believer",
        duration: 200,
        artistName: "Imagine Dragons",
        albumName: "Evolve",
        releaseDate: "2017-02-01",
        download: nil,
        waveformData: nil,
        size: 5_242_880
    )

    track.downloadState = .downloading
    return track
}
