//
//  EmptyGenreCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.06.2026.
//

import SwiftUI

struct EmptyGenreCell: View {

    // MARK: - Main Body

    var body: some View {
        RoundedRectangle(cornerRadius: GlobalConstants.GenreCell.cornerRadius)
            .fill(Color(.secondarySystemBackground).gradient.opacity(0.7))
            .frame(
                width: GlobalConstants.GenreCell.width,
                height: GlobalConstants.GenreCell.height
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlobalConstants.GenreCell.cornerRadius)
                    .stroke(
                        Color(.separator),
                        lineWidth: GlobalConstants.GenreCell.borderWidth
                    )
            )
    }
}

#Preview {
    EmptyGenreCell()
}
