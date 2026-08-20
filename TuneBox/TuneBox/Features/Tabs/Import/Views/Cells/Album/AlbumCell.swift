//
//  AlbumCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI

enum AlbumDisplayContext {
    case artist
    case album
}

struct AlbumCell: View {

    // MARK: - Properties. Public

    let album: MusicLibrary.Album
    let displayContext: AlbumDisplayContext
    let shouldLoadCover: Bool
    let defaultPadding: CGFloat = GlobalConstants.Cell.defaultPadding
    let onTapGesture: () -> Void

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 10) {
                ZStack {
                    CoverView(
                        coverPath: album.cover,
                        size: GlobalConstants.Cell.imageSize,
                        cornerRadius: GlobalConstants.Cell.imageCornerRadius
                    )

                    if shouldLoadCover {
                        SpinnerView(
                            size: .large,
                            color: .gray
                        )
                    }
                }

                VStack(spacing: subtitle?.isNotEmpty == true ? 4 : 0) {
                    if title.isNotEmpty {
                        Text(title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(GlobalConstants.Cell.textLineLimit)
                            .font(titleFont)
                    }

                    if let subtitle, subtitle.isNotEmpty {
                        Text(subtitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(GlobalConstants.Cell.textLineLimit)
                            .font(subtitleFont)
                    }
                }
            }
            .padding(.horizontal, defaultPadding)

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.leading, 82)
                .padding(.trailing, defaultPadding)
        }
        .padding(.top, 5)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapGesture()
        }
    }

    // MARK: - Properties. Private

    private var title: String {
        displayContext == .artist ? album.name : album.artist
    }

    private var subtitle: String? {
        displayContext == .artist ? album.date : album.name
    }

    private var titleFont: Font {
        displayContext == .artist
            ? GlobalConstants.Cell.titleFont
            : GlobalConstants.Cell.subtitleFont
    }

    private var subtitleFont: Font {
        displayContext == .artist
            ? GlobalConstants.Cell.subtitleFont
            : GlobalConstants.Cell.titleFont
    }
}

#Preview {
    AlbumCell(
        album: MusicLibrary.Album(
            id: "1",
            name: "Random Access Memories",
            artist: "Daft Punk",
            date: "2026",
            tracks: [],
            cover: nil
        ),
        displayContext: .album,
        shouldLoadCover: true,
        onTapGesture: {}
    )
}
