//
//  View+leadingTapArea.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 11.09.2026.
//

import SwiftUI

extension View {

    func leadingTapArea(
        fraction: CGFloat = 0.4,
        action: @escaping () -> Void
    ) -> some View {
        overlay(alignment: .leading) {
            GeometryReader { geometry in
                Color.clear
                    .frame(width: geometry.size.width * fraction)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        action()
                    }
            }
        }
    }

}
