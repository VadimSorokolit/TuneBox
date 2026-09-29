//
//  EmptyTracksStateModifier.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 26.06.2026.
//

import SwiftUI

struct EmptyTracksStateModifier: ViewModifier {
    let showsEmptyState: Bool
    var isKeyboardVisible: Bool = false

    private enum Constants {
        static let keyboardLift: CGFloat = 120
        static let animationDuration: Double = 0.25
    }

    func body(content: Content) -> some View {
        if showsEmptyState {
            ContentUnavailableView(
                L10n.Import.noTracks,
                systemImage: "music.note"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: isKeyboardVisible ? -Constants.keyboardLift : 0)
            .animation(
                .easeInOut(duration: Constants.animationDuration),
                value: isKeyboardVisible
            )
        } else {
            content
        }
    }
}
