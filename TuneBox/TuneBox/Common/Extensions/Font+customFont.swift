//
//  Font+customFont.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.06.2026.
//

import Foundation
import SwiftUI

extension Font {

    static func customFont(_ font: CustomFontFamily, size: CGFloat) -> Font {
        .custom(font.name, size: size)
    }

}

extension Font {

    // MARK: - JetBrains Mono

    static let jetBrainsMonoRegular10: Font = customFont(.jetBrainsMono(.regular), size: 10.0)
    static let jetBrainsMonoRegular12: Font = customFont(.jetBrainsMono(.regular), size: 12.0)
    static let jetBrainsMonoRegular14: Font = customFont(.jetBrainsMono(.regular), size: 14.0)

    static let jetBrainsMonoMedium12: Font = customFont(.jetBrainsMono(.medium), size: 12.0)
    static let jetBrainsMonoMedium14: Font = customFont(.jetBrainsMono(.medium), size: 14.0)

    static let jetBrainsMonoSemiBold14: Font = customFont(.jetBrainsMono(.semiBold), size: 14.0)

    static let jetBrainsMonoBold14: Font = customFont(.jetBrainsMono(.bold), size: 14.0)
    static let jetBrainsMonoBold16: Font = customFont(.jetBrainsMono(.bold), size: 16.0)

    // MARK: - Satoshi

    static let satoshiExtraBold24: Font = customFont(.satoshi(.extraBold), size: 24.0)
    static let satoshiExtraBold28: Font = customFont(.satoshi(.extraBold), size: 28.0)
    static let satoshiExtraBold32: Font = customFont(.satoshi(.extraBold), size: 32.0)

    static let satoshiBold16: Font = customFont(.satoshi(.bold), size: 16.0)
    static let satoshiBold18: Font = customFont(.satoshi(.bold), size: 18.0)
    static let satoshiBold20: Font = customFont(.satoshi(.bold), size: 20.0)
    static let satoshiBold24: Font = customFont(.satoshi(.bold), size: 24.0)
    static let satoshiBold34: Font = customFont(.satoshi(.bold), size: 34.0)

    static let satoshiMedium12: Font = customFont(.satoshi(.medium), size: 12.0)
    static let satoshiMedium14: Font = customFont(.satoshi(.medium), size: 14.0)
    static let satoshiMedium16: Font = customFont(.satoshi(.medium), size: 16.0)
    static let satoshiMedium18: Font = customFont(.satoshi(.medium), size: 18.0)
    static let satoshiMedium34: Font = customFont(.satoshi(.medium), size: 34.0)

    static let satoshiRegular10: Font = customFont(.satoshi(.regular), size: 10.0)
    static let satoshiRegular12: Font = customFont(.satoshi(.regular), size: 12.0)
    static let satoshiRegular14: Font = customFont(.satoshi(.regular), size: 14.0)
    static let satoshiRegular16: Font = customFont(.satoshi(.regular), size: 16.0)
    static let satoshiRegular18: Font = customFont(.satoshi(.regular), size: 18.0)
    static let satoshiRegular34: Font = customFont(.satoshi(.regular), size: 34.0)

    // MARK: - Space Grotesk

    static let spaceGroteskBold18: Font = customFont(.spaceGrotesk(.bold), size: 18.0)
    static let spaceGroteskBold20: Font = customFont(.spaceGrotesk(.bold), size: 20.0)

    static let spaceGroteskSemiBold16: Font = customFont(.spaceGrotesk(.semiBold), size: 16.0)
    static let spaceGroteskSemiBold18: Font = customFont(.spaceGrotesk(.semiBold), size: 18.0)

    static let spaceGroteskMedium14: Font = customFont(.spaceGrotesk(.medium), size: 14.0)
    static let spaceGroteskMedium16: Font = customFont(.spaceGrotesk(.medium), size: 16.0)

    static let spaceGroteskRegular14: Font = customFont(.spaceGrotesk(.regular), size: 14.0)
    static let spaceGroteskRegular16: Font = customFont(.spaceGrotesk(.regular), size: 16.0)

    static let spaceGroteskLight14: Font = customFont(.spaceGrotesk(.light), size: 14.0)

}
