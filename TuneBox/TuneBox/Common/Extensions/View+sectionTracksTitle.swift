//
//  View+sectionTracksTitle.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.06.2026.
//

import SwiftUI

extension View {

    func sectionTracksTitle(
        _ title: String,
        suffix: String? = nil,
        font: Font = .headline,
        background: Color = Color(.systemBackground),
        foregroundStyle: Color = Color(.label),
        topPadding: CGFloat = 10,
        bottomPadding: CGFloat = 10,
        horizontalPadding: CGFloat = 26,
        hasSeparator: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            Text("\(title) \(suffix ?? "")")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .background(background)
                .foregroundStyle(foregroundStyle)
                .font(font)

            if hasSeparator {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color(.separator))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalPadding)
            }
        }
    }

}
