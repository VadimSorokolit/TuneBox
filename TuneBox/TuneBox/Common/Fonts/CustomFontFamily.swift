//
//  CustomFontFamily.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.06.2026.
//

import Foundation

enum CustomFontFamily {
    enum JetBrainsMono: String {
        case extraBold = "JetBrainsMono-ExtraBold"
        case bold = "JetBrainsMono-Bold"
        case semiBold = "JetBrainsMono-SemiBold"
        case medium = "JetBrainsMono-Medium"
        case regular = "JetBrainsMono-Regular"
        case light = "JetBrainsMono-Light"
        case extraLight = "JetBrainsMono-ExtraLight"
        case thin = "JetBrainsMono-Thin"
    }

    enum Satoshi: String {
        case extraBold = "Satoshi-Black"
        case bold = "Satoshi-Bold"
        case medium = "Satoshi-Medium"
        case regular = "Satoshi-Regular"
        case light = "Satoshi-Light"
    }

    enum SpaceGrotesk: String {
        case bold = "SpaceGrotesk-Bold"
        case semiBold = "SpaceGrotesk-SemiBold"
        case medium = "SpaceGrotesk-Medium"
        case regular = "SpaceGrotesk-Regular"
        case light = "SpaceGrotesk-Light"
    }

    case jetBrainsMono(JetBrainsMono)
    case satoshi(Satoshi)
    case spaceGrotesk(SpaceGrotesk)

    var name: String {
        switch self {
            case .satoshi(let weight):
                return weight.rawValue

            case .jetBrainsMono(let weight):
                return weight.rawValue

            case .spaceGrotesk(let weight):
                return weight.rawValue
        }
    }
}
