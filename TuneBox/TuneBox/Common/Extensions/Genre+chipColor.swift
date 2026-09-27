//
//  Genre+chipColor.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.09.2026.
//

import SwiftUI

extension Genre: ChipSegmentedItem {

    var title: String { displayName }

    var chipColor: Color {
        switch self {
            case .all:
                Color(hex: 0x007AFF)

            case .pop:
                Color(hex: 0xFF2D55)

            case .rock:
                Color(hex: 0xFF6B00)

            case .jazz:
                Color(hex: 0xAF52DE)

            case .classic:
                Color(hex: 0xC9A227)

            case .electronic:
                Color(hex: 0x00C7BE)
        }
    }

}
