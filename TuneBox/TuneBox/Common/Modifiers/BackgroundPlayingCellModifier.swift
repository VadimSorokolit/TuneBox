//
//  BackgroundPlayingCellModifier.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.09.2026.
//

import SwiftUI

private struct BackgroundPlayingCellModifier: ViewModifier {
    let isPlaying: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if isPlaying {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.gray.opacity(0.1))
                        .padding(.horizontal, 8)
                }
            }
    }
}

extension View {

    func backgroundPlayingCell(isPlaying: Bool) -> some View {
        modifier(BackgroundPlayingCellModifier(isPlaying: isPlaying))
    }

}
