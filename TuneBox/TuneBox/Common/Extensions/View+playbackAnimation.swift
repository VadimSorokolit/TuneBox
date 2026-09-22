//
//  View+playbackAnimation.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 22.09.2026.
//

import SwiftUI

extension View {

    func playbackAnimation(_ isPlaying: Bool) -> some View {
        self.animation(.snappy(duration: 0.2), value: isPlaying)
    }

}
