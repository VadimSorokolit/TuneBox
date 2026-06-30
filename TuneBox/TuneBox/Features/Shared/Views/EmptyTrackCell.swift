//
//  EmptyTrackCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.06.2026.
//

import SwiftUI

struct EmptyTrackCell: View {
    @Environment(\.themeManager) var theme

    let isSelected: Bool
    let cornerRadius: CGFloat = 10
    let height: CGFloat = 50
    let borderWidth: CGFloat = 0.5

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(background)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private var background: Color {
        isSelected
        ? theme.tokens.cellBackground.opacity(0.6)
        : theme.tokens.cellBackground
    }

    private var borderColor: Color {
        isSelected
        ? .blue.opacity(0.8)
        : theme.tokens.cellBorder
    }
}

#Preview {
    EmptyTrackCell(isSelected: false)
}
