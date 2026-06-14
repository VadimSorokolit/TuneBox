//
//  EmptyTrackCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.06.2026.
//

import SwiftUI

struct EmptyTrackCell: View {
    @Environment(\.themeManager) var theme

    let cornerRadius: CGFloat = 10
    let height: CGFloat = 50
    let borderWidth: CGFloat = 0.5

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .foregroundStyle(theme.tokens.cellBackground)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(theme.tokens.cellBorder, lineWidth: borderWidth)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

#Preview {
    EmptyTrackCell()
}
