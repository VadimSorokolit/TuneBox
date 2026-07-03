//
//  PlaylistCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 01.07.2026.
//

import SwiftUI

struct PlaylistCell: View {
    let playlist: PlaylistEntity
    let customPadding: CGFloat = 10
    let cornerRadius: CGFloat = 12
    let cellHeight: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let data = playlist.coverImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .padding(20)
                        .foregroundStyle(.secondary)
                        .background(Color.gray.opacity(0.1))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(cornerRadius)

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

                Circle()
                    .fill(.white)
                    .frame(width: 24, height: 24)
            }
        }
        .frame(height: cellHeight)
        .frame(maxWidth: .infinity)
        .padding(customPadding)
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    PlaylistCell(playlist: PlaylistEntity(name: "Downloaded"))
}
