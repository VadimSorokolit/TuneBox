//
//  PlaylistCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 01.07.2026.
//

import SwiftUI

struct PlaylistCell: View {

    // MARK: - Properties. Public

    let playlist: PlaylistEntity
    let onCellTap: () -> Void
    let onPlayBtnTap: () -> Void
    let onChangeCoverBtnTap: () -> Void
    let onAddTracksBtnTap: () -> Void
    let onRenamePlaylistBtnTap: () -> Void
    let onDeletePlaylistBtnTap: () -> Void

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 0) {
            coverView

            Text(playlist.title)
                .lineLimit(2)
                .font(.headline)
                .padding(.top, customPadding)

            Spacer()

            HStack(alignment: .bottom) {
                Text("\(playlist.tracks.count)")
                    .lineLimit(1)
                    .frame(width: 60, alignment: .leading)
                    .offset(y: -3)

                Spacer()

                Menu {
                    Button(
                        action: {
                            onPlayBtnTap()
                        }, label: {
                            Label("Play all", systemImage: "play.fill")
                        }
                    )

                    Button(
                        action: {
                            onChangeCoverBtnTap()
                        }, label: {
                            Label("Change Cover", systemImage: "photo")
                        }
                    )

                    if playlist.type == .custom {
                        Button(
                            action: {
                                onAddTracksBtnTap()
                            }, label: {
                                Label("Add Tracks", systemImage: "plus")
                            }
                        )

                        Button(
                            action: {
                                onRenamePlaylistBtnTap()
                            }, label: {
                                Label("Rename Playlist", systemImage: "pencil")
                            }
                        )
                    }

                    Button(
                        role: .destructive,
                        action: {
                            onDeletePlaylistBtnTap()
                        },
                        label: {
                            Label("Delete Playlist", systemImage: "trash")
                        }
                    )
                } label: {
                    Circle()
                        .fill(.clear)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.white)
                        }

                }
            }
        }
        .frame(height: cellHeight)
        .frame(maxWidth: .infinity)
        .padding(customPadding)
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onTapGesture {
            onCellTap()
        }
    }

    // MARK: - Properties. Private

    private let customPadding: CGFloat = 10
    private let cornerRadius: CGFloat = 12
    private let cellHeight: CGFloat = 230

    @ViewBuilder
    private var coverView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.1))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let data = playlist.coverImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    PlaylistCell(
        playlist: PlaylistEntity(title: "Default"),
        onCellTap: {},
        onPlayBtnTap: {},
        onChangeCoverBtnTap: {},
        onAddTracksBtnTap: {},
        onRenamePlaylistBtnTap: {},
        onDeletePlaylistBtnTap: {}
    )
}
