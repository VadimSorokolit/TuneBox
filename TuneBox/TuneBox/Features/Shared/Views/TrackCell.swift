//
//  TrackCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 03.06.2026.
//

import SwiftUI
import SDWebImageSwiftUI

struct TrackCell: View {

    // MARK: Initializer

    init(
        track: TrackEntity,
        searchQuery: String? = nil,
        isSelected: Bool = false,
        editMode: EditMode = .inactive,
        onButtonTap: @escaping () -> Void,
        onCellTap: (() -> Void)? = nil
    ) {
        self.track = track
        self.searchQuery = searchQuery
        self.isSelected = isSelected
        self.editMode = editMode
        self.onButtonTap = onButtonTap
        self.onCellTap = onCellTap
    }

    // MARK: - Main Body

    var body: some View {
        ZStack {
            EmptyTrackCell(isSelected: isSelected)

            HStack {
                HStack(spacing: 10) {
                    trackImage

                    VStack(alignment: .leading, spacing: 2) {
                        HighlightedText(
                            text: track.songName,
                            searchQuery: searchQuery
                        )
                        .font(.satoshi.medium.size(14))
                        .lineLimit(1)

                        HStack(spacing: 6) {
                            HighlightedText(
                                text: track.artistName,
                                searchQuery: searchQuery
                            )
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

                if editMode == .inactive {
                    Button(action: {
                            onButtonTap()
                        },
                        label: {
                            ZStack {
                                if track.downloadState != .completed,
                                   track.downloadState != .idle {
                                    Circle()
                                        .foregroundStyle(.clear)
                                        .overlay(
                                            content: {
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 0.8)
                                            }
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
                            .frame(size: 25)
                        }
                    )
                    .accessibilityHint(accessibilityLabel)
                }
            }
            .padding(.horizontal)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onCellTap?()
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    // MARK: - Properties. Private

    @Environment(\.themeManager) private var theme
    private let track: TrackEntity
    private let searchQuery: String?
    private let editMode: EditMode
    private let isSelected: Bool
    private let onButtonTap: () -> Void
    private let onCellTap: (() -> Void)?
    private let cellCornerRadius: CGFloat = 10
    private let imageSize: CGFloat = 35
    private let imageCornerRadius: CGFloat = 10

    private var accessibilityLabel: String {
        switch track.downloadState {
            case .idle:
                "Start download track"

            case .queued:
                "Cancel download"

            case .downloading:
                "Pause download"

            case .paused:
                "Resume download"

            case .completed:
                "Delete track"

            case .failed:
                "Retry download"
        }
    }

    @ViewBuilder
    private var trackImage: some View {
        if track.source == .imported {
            if let artworkPath = track.imagePath,
               let image = UIImage(contentsOfFile: artworkPath) {

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(size: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))

            } else {
                customPlaceholder
                    .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
            }
        } else if let url = track.imageURL {
            WebImage(
                url: url,
                content: { image in
                    image
                        .resizable()
                        .scaledToFit()
                },
                placeholder: {
                    customPlaceholder
                }
            )
            .frame(size: imageSize)
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
            .frame(size: imageSize)
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

    return TrackCell(track: track) {
        print("tap")
    }
}
