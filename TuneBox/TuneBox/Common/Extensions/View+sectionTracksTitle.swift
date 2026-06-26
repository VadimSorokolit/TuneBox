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
        horizontalPadding: CGFloat = 26
    ) -> some View {
        Text("\(title) \(suffix ?? "")")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .foregroundStyle(Color(.label))
            .font(.headline)
    }

}
