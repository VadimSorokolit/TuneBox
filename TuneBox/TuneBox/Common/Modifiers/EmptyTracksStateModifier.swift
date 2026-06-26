//
//  EmptyTracksStateModifier.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 26.06.2026.
//

import SwiftUI

struct EmptyTracksStateModifier: ViewModifier {
    let showsEmptyState: Bool

    func body(content: Content) -> some View {
        if showsEmptyState {
            ContentUnavailableView(
                "No Tracks",
                systemImage: "music.note"
            )
        } else {
            content
        }
    }
}
