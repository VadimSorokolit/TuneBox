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
    var titleLineLimit: Int = 1
    var subtitleLineLimit: Int = 1
    var showSubtitle: Bool = true
}

struct GenreCell: View {
    let track: TrackEntity
    let onDownloadTap: () -> Void
    var configuration: GenreCellConfiguration = .init()

    var body: some View {
        ZStack {
            EmptyGenreCell()

            VStack(alignment: .leading, spacing: configuration.spacing) {
                trackImage
                    .aspectRatio(configuration.imageAspectRatio, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: configuration.imageCornerRadius))

                Text(track.songName)
                    .font(.satoshi.medium.size(14))
                    .foregroundStyle(.primary)
                    .lineLimit(configuration.titleLineLimit)

                if configuration.showSubtitle {
                    Text(track.albumName)
                        .font(.satoshi.medium.size(12))
                        .foregroundStyle(.secondary)
                        .lineLimit(configuration.subtitleLineLimit)
                }

                Spacer()

                if configuration.showDuration || configuration.showDownloadButton {
                    bottomRow
                }
            }
            .padding(configuration.padding)
        }
        .frame(width: 100, height: 200)
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
                    .font(.jetBrainsMono.regular.size(10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if configuration.showDownloadButton {
                Button(action: onDownloadTap) {
                    downloadButton
                }
                .buttonStyle(.plain)
                .accessibilityLabel(downloadButtonAccessibility)
            }
        }
    }

    private var downloadButton: some View {
        let progress = min(max(track.downloadingProgress, 0), 1)

        return ZStack {
            if track.downloadState != .completed,
               track.downloadState != .idle {
                Circle()
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1.2)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.green,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            stateImage
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(iconColor)
        }
        .frame(width: 28, height: 28)
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

    private var downloadButtonAccessibility: String {
        switch track.downloadState {
            case .idle:
                return "Download \(track.songName)"
            case .queued:
                return "Queued"
            case .downloading:
                return "Pause download"
            case .paused:
                return "Resume download"
            case .completed:
                return "Delete downloaded file"
            case .failed:
                return "Retry download"
        }
    }

    @ViewBuilder
    private var trackImage: some View {
        if let url = track.imageURL {
            WebImage(url: url) { image in
                image.resizable().scaledToFill()
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
        onDownloadTap: {}
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
