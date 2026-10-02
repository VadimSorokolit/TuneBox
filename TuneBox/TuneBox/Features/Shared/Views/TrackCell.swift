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
        showsMenu: Bool = false,
        editMode: EditMode = .inactive,
        onButtonTap: (() -> Void)? = nil,
        onEditAudioTagsTap: (() -> Void)? = nil,
        onDeleteFromPlaylistTap: (() -> Void)? = nil,
        onDeleteFromDevice: @escaping () -> Void = {},
        onCellTap: (() -> Void)? = nil
    ) {
        self.track = track
        self.searchQuery = searchQuery
        self.isSelected = isSelected
        self.showsMenu = showsMenu
        self.editMode = editMode
        self.onButtonTap = onButtonTap
        self.onEditAudioTagsTap = onEditAudioTagsTap
        self.onDeleteFromPlaylistTap = onDeleteFromPlaylistTap
        self.onDeleteFromDeviceTap = onDeleteFromDevice
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
                        .font(.satoshi.medium.size(GlobalConstants.TrackCell.primaryTextSize))
                        .lineLimit(2)

                        HStack(spacing: 6) {
                            HighlightedText(
                                text: track.artistName,
                                searchQuery: searchQuery
                            )
                            .font(.satoshi.medium.size(GlobalConstants.TrackCell.primaryTextSize))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                            Text("•")
                                .font(.satoshi.medium.size(GlobalConstants.TrackCell.primaryTextSize))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text("\(track.formattedDuration)")
                                .font(.jetBrainsMono.regular.size(GlobalConstants.TrackCell.durationTextSize))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                if showsMenu {
                    Menu {
                        if track.source == .imported {
                            Button(action: {
                                onEditAudioTagsTap?()
                            }, label: {
                                Label(L10n.Track.editTags, systemImage: "pencil")
                            })

                            Button(
                                role: .destructive,
                                action: {
                                    onDeleteFromPlaylistTap?()
                                },
                                label: {
                                    Label(L10n.Track.deleteFromPlaylist, systemImage: "minus.circle")
                                }
                            )
                        }

                        Button(
                            role: .destructive,
                            action: {
                                onDeleteFromDeviceTap()
                            },
                            label: {
                                Label(L10n.Track.deleteFromDevice, systemImage: "trash")
                            }
                        )
                    } label: {
                        Circle()
                            .fill(.clear)
                            .frame(size: Constants.menuButtonSize)
                            .overlay {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: Constants.menuIconSize, weight: .regular))
                                    .foregroundColor(.black)
                            }
                    }
                    .disabled(editMode == .active)
                    .opacity(editMode == .active ? 0.0 : 1)
                    .padding(.leading, 5)
                } else {
                    TrackDownloadButton(track: track) {
                        onButtonTap?()
                    }
                }
            }
            .padding(.horizontal)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onCellTap?()
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    // MARK: - Properties. Private

    @Environment(\.themeManager) private var theme
    private let track: TrackEntity
    private let searchQuery: String?
    private let editMode: EditMode
    private let isSelected: Bool
    private let showsMenu: Bool
    private let onButtonTap: (() -> Void)?
    private let onCellTap: (() -> Void)?
    private let onEditAudioTagsTap: (() -> Void)?
    private let onDeleteFromPlaylistTap: (() -> Void)?
    private let onDeleteFromDeviceTap: () -> Void

    private enum Constants {
        static let menuIconSize: CGFloat = 20
        static let menuButtonSize: CGFloat = 26
    }

    @ViewBuilder
    private var trackImage: some View {
        if track.source == .imported,
           let storedPath = track.imagePath,
           let coverURL = AudioMetadataService.coverURL(for: storedPath),
           let data = try? Data(contentsOf: coverURL),
           let image = UIImage(data: data) {

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(size: GlobalConstants.TrackCell.imageSize)
                .clipShape(RoundedRectangle(cornerRadius: GlobalConstants.TrackCell.imageCornerRadius))
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
            .frame(size: GlobalConstants.TrackCell.imageSize)
            .clipShape(RoundedRectangle(cornerRadius: GlobalConstants.TrackCell.imageCornerRadius))
        } else {
            customPlaceholder
                .clipShape(RoundedRectangle(cornerRadius: GlobalConstants.TrackCell.imageCornerRadius))
        }
    }

    private var customPlaceholder: some View {
        Image(systemName: "music.note")
            .resizable()
            .scaledToFit()
            .padding(16)
            .foregroundStyle(.secondary)
            .frame(size: GlobalConstants.TrackCell.imageSize)
            .background(Color.gray.opacity(0.1))
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

    return TrackCell(track: track)
}
