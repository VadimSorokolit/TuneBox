//
//  TrackCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 03.06.2026.
//

import SwiftUI
import SDWebImageSwiftUI

struct TrackCell: View {
    @Environment(\.themeManager) var theme
    let track: TrackEntity
    let onTap: () -> Void

    let cellCornerRadius: CGFloat = 10
    let imageSize: CGFloat = 35
    let imageCornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            EmptyTrackCell()

            HStack {
                HStack(spacing: 10) {
                    trackImage

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.songName)
                            .font(.satoshi.medium.size(14))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(track.artistName)
                                .font(.satoshi.medium.size(12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text("•")
                                .font(.satoshi.medium.size(12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text("\(track.formattedDuration)")
                                .font(.jetBrainsMono.regular.size(10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Button(action: {
                    onTap()
                }, label: {
                    ZStack {
                        if track.downloadState != .completed,
                           track.downloadState != .idle {
                            Circle()
                                .foregroundStyle(.clear)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 0.8)
                                )

                            Circle()
                                .trim(from: 0, to: track.downloadingProgress)
                                .stroke(
                                    Color.green,
                                    style: StrokeStyle(
                                        lineWidth: 1,
                                        lineCap: .round
                                    )
                                )
                                .rotationEffect(.degrees(-90))
                        }

                        buttonImage
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(width: 25, height: 25)
                })
            }
            .padding(.horizontal)
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var trackImage: some View {
        if let url = track.imageURL {
            WebImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                customPlaceholder
            }
            .frame(width: imageSize, height: imageSize)
            .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
        } else {
            customPlaceholder
                .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
        }
    }

    private var customPlaceholder: some View {
        Image(systemName: "music.note")
            .resizable()
            .scaledToFit()
            .padding(16)
            .foregroundStyle(.secondary)
            .frame(width: imageSize, height: imageSize)
            .background(Color.gray.opacity(0.1))
    }

    @ViewBuilder
    private var buttonImage: some View {
        switch track.downloadState {
            case .idle:
                if track.fileState == .removed {
                    Image(systemName: "cloud")
                        .foregroundStyle(.black)
                } else {
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.black)
                }

            case .queued:
                Image(systemName: "clock")
                    .foregroundStyle(Color.yellow)

            case .downloading:
                Image(systemName: "pause.fill")
                    .foregroundStyle(Color.red)

            case .paused:
                Image(systemName: "play.fill")
                    .foregroundStyle(Color.blue)

            case .completed:
                Image(systemName: "trash.fill")
                    .foregroundStyle(Color.red)

            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Color.orange)
        }
    }
}

#Preview {
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

    track.downloadState = .idle

    return TrackCell(
        track: track,
        onTap: {
            print("tap")
        }
    )
}
