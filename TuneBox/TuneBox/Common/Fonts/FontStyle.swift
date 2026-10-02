//
//  FontStyle.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.06.2026.
//

import SwiftUI
import UIKit
import CoreText

struct FontStyle {
    let name: String
    /// Value for the `wght` axis of a variable font.
    var variableWeight: CGFloat?

    func size(_ size: CGFloat) -> Font {
        guard let variableWeight else {
            return .custom(name, size: size)
        }

        let wghtAxisTag = 0x77676874
        let descriptor = UIFontDescriptor(name: name, size: size)
            .addingAttributes([
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [
                    wghtAxisTag: variableWeight
                ]
            ])

        return Font(UIFont(descriptor: descriptor, size: size))
    }

    /// If the text has Cyrillic, uses the system font with the weight you pass.
    func size(_ size: CGFloat, for text: String, _ cyrillicWeight: Font.Weight) -> Font {
        text.containsCyrillic
            ? .system(size: size, weight: cyrillicWeight)
            : self.size(size)
    }
}

struct JetBrainsMonoFamily {
    let extraBold = FontStyle(name: "JetBrainsMono-ExtraBold")
    let bold = FontStyle(name: "JetBrainsMono-Bold")
    let semiBold = FontStyle(name: "JetBrainsMono-SemiBold")
    let medium = FontStyle(name: "JetBrainsMono-Medium")
    let regular = FontStyle(name: "JetBrainsMono-Regular")
    let light = FontStyle(name: "JetBrainsMono-Light")
    let extraLight = FontStyle(name: "JetBrainsMono-ExtraLight")
    let thin = FontStyle(name: "JetBrainsMono-Thin")
}

struct SatoshiFamily {
    let extraBold = FontStyle(name: "Satoshi-Black")
    let bold = FontStyle(name: "Satoshi-Bold")
    let semiBold = FontStyle(name: "SatoshiVariable-Bold", variableWeight: 600)
    let medium = FontStyle(name: "Satoshi-Medium")
    let regular = FontStyle(name: "Satoshi-Regular")
    let light = FontStyle(name: "Satoshi-Light")
}

struct SpaceGroteskFamily {
    let bold = FontStyle(name: "SpaceGrotesk-Bold")
    let semiBold = FontStyle(name: "SpaceGrotesk-SemiBold")
    let medium = FontStyle(name: "SpaceGrotesk-Medium")
    let regular = FontStyle(name: "SpaceGrotesk-Regular")
    let light = FontStyle(name: "SpaceGrotesk-Light")
}
