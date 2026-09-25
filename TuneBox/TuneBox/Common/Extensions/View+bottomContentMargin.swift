//
//  View+bottomContentMargin.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 28.07.2026.
//

import SwiftUI

enum BottomLayout {
    static let seExtraInset: CGFloat = 16

    static func inset(
        base: CGFloat = 10,
        adjustment: CGFloat = 0,
        isPlayerVisible: Bool,
        isPlaying: Bool,
        isTabBarVisible: Bool,
        screenHeight: CGFloat = .infinity
    ) -> CGFloat {
        base
        - adjustment
        + (isPlayerVisible
           ? GlobalConstants.CompactPlayer.height
           : 0
        )
        + (isTabBarVisible
           ? GlobalConstants.Screen.defaultHeight
           : GlobalConstants.CompactPlayer.bottomPadding
        )
        + (GlobalConstants.Device.isPad && isPlayerVisible
           ? GlobalConstants.CompactPlayer.bottomPadding
           : 0
        )
        + (screenHeight > GlobalConstants.Screen.seHeight
           ? 0
           : seExtraInset
        )
    }
}

extension View {

    func bottomContentMargin(
        _ base: CGFloat = 0,
        _ adjustment: CGFloat = 10,
        isPlayerVisible: Bool,
        isPlaying: Bool,
        isTabBarVisible: Bool
    ) -> some View {
        modifier(
            BottomContentMarginModifier(
                base: base,
                adjustment: adjustment,
                isPlayerVisible: isPlayerVisible,
                isPlaying: isPlaying,
                isTabBarVisible: isTabBarVisible
            )
        )
    }

}

private struct BottomContentMarginModifier: ViewModifier {

    @Environment(\.screenHeight) private var screenHeight

    let base: CGFloat
    let adjustment: CGFloat
    let isPlayerVisible: Bool
    let isPlaying: Bool
    let isTabBarVisible: Bool

    func body(content: Content) -> some View {
        content
            .contentMargins(
                .bottom,
                BottomLayout.inset(
                    base: base,
                    adjustment: adjustment,
                    isPlayerVisible: isPlayerVisible,
                    isPlaying: isPlaying,
                    isTabBarVisible: isTabBarVisible,
                    screenHeight: screenHeight
                )
            )
            .animation(.easeInOut(duration: 0.35), value: isPlaying)
    }

}
