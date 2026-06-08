//
//  EmptyGenreCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.06.2026.
//

import SwiftUI

struct EmptyGenreCell: View {
    let cornerRadius: CGFloat = 10
    let borderWidth: CGFloat = 0.5

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.secondarySystemBackground))
            .frame(width: 100, height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(.separator), lineWidth: borderWidth)
            )
    }

}

#Preview {
    EmptyGenreCell()
}
