//
//  PlaylistCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 01.07.2026.
//

import SwiftUI

struct PlaylistCell: View {
    let model: PlaylistEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.title)
                .font(.headline)

            Text("\(model.tracks.count) tracks")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    PlaylistCell(
        model: PlaylistEntity(
            name: "Downloaded",
            isProtected: true
        )
    )

    .padding()
}
