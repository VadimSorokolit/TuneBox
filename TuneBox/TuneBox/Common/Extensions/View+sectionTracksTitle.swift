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
        background: Color = Color(.systemBackground),
        foregroundStyle: Color = Color(.label),
        horizontalPadding: CGFloat = 26
    ) -> some View {
        Text("\(title) \(suffix ?? "")")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 10)
            .background(background)
            .foregroundStyle(foregroundStyle)
            .font(.headline)
    }

}
