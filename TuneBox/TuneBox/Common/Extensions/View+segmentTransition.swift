//
//  View+segmentTransition.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 16.07.2026.
//

import SwiftUI

extension View {

    func segmentTransition(_ direction: SlideDirection) -> some View {
        let insertion: Edge = direction == .forward ? .trailing : .leading
        let removal: Edge = direction == .forward ? .leading : .trailing

        return self.transition(
            .asymmetric(
                insertion: .move(edge: insertion).combined(with: .opacity),
                removal: .move(edge: removal).combined(with: .opacity)
            )
        )
    }

}
