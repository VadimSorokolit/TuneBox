//
//  CoverCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 11.08.2026.
//

import SwiftUI

struct CoverCell: View {

    // MARK: - Properties. Public

    let coverPath: String
    let size: CGFloat
    let cornerRadius: CGFloat
    var isSelected: Bool
    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?

    // MARK: - Initializer

    init(
        coverPath: String,
        size: CGFloat, cornerRadius: CGFloat,
        isSelected: Bool,
        onTap: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil
    ) {
        self.coverPath = coverPath
        self.size = size
        self.cornerRadius = cornerRadius
        self.isSelected = isSelected
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    // MARK: - Main Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CoverView(
                coverPath: coverPath,
                size: size,
                cornerRadius: cornerRadius
            )

            if isSelected {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .frame(width: size, height: size)

                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .font(.system(size: 22))
                    .padding(6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            onLongPress?()
        }
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}
