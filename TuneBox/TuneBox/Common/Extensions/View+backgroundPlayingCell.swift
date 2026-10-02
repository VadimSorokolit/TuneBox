//
//  View+backgroundPlayingCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.10.2026.
//

import SwiftUI

extension View {

    func backgroundPlayingCell(isPlaying: Bool) -> some View {
        modifier(BackgroundPlayingCellModifier(isPlaying: isPlaying))
    }

}
