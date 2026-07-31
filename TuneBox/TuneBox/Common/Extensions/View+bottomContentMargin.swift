//
//  View+bottomContentMargin.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 28.07.2026.
//

import SwiftUI

extension View {

    func bottomContentMargin(
        _ base: CGFloat = 20,
        isPlayerVisible: Bool
    ) -> some View {
        contentMargins(
            .bottom,
            isPlayerVisible
            ? GlobalConstants.Screen.defaultBottomPadding + base
            : base
        )
    }

}
