//
//  View+bottomContentMargin.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 28.07.2026.
//

import SwiftUI

enum BottomLayout {
    static func inset(
        base: CGFloat = 10,
        adjustment: CGFloat = 0,
        isPlayerVisible: Bool,
        isTabBarVisible: Bool
    ) -> CGFloat {
        base
            - adjustment
            + (isPlayerVisible ? GlobalConstants.CompactPlayer.defaultHeight : 0)
            + (isTabBarVisible ? GlobalConstants.Screen.defaultHeight : 0)
    }
}

extension View {

    func bottomContentMargin(
        _ base: CGFloat = 0,
        _ adjustment: CGFloat = 10,
        isPlayerVisible: Bool,
        isTabBarVisible: Bool
    ) -> some View {
        contentMargins(
            .bottom,
            BottomLayout.inset(
                base: base,
                adjustment: adjustment,
                isPlayerVisible: isPlayerVisible,
                isTabBarVisible: isTabBarVisible
            )
        )
    }

}
