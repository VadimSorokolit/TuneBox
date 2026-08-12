//
//  GlobalConstants.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.05.2026.
//

import Foundation
import SwiftUI

enum GlobalConstants {
    static let bytesInGigabyte: Double = 1e9
    static let downloadedFilePrefix = "track"

    enum Screen {
        static let regularWidth: CGFloat = 393
        static let defaultHeight: CGFloat = 60
    }

    enum CompactPlayer {
        static let defaultHeight: CGFloat = 90
    }

    enum UserDefaultsKey {
        static let playlistID: String = "UserDefaultsPlaylistIdKey"
    }

    enum AppColor {
        static let defaultBackground = SwiftUI.Color(hex: 0xFCFCFC)
    }

    enum Cell {
        static let imageSize: CGFloat = 46
        static let imageCornerRadius: CGFloat = 8
        static let textLineLimit: Int = 4
        static let defaultPadding: CGFloat = 19
        static let titleFont: Font = .system(size: 16, weight: .medium)
        static let subtitleFont: Font = .system(size: 10, weight: .regular)
    }
}
