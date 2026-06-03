//
//  FontStyle.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.06.2026.
//

import SwiftUI

struct FontStyle {
    let name: String

    func size(_ size: CGFloat) -> Font {
        .custom(name, size: size)
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
