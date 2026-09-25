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

    enum Device {
        static var isPad: Bool {
            UIDevice.current.model.contains("iPad")
        }
    }

    enum API {
        static let fallbackBaseURL = "google.com"
        static let invalidURLMessage = "Invalid baseURL:"
    }

    enum Screen {
        static let regularWidth: CGFloat = 393
        static let seHeight: CGFloat = 667
        static let defaultHeight: CGFloat = 60
        static let horizontalInset: CGFloat = 26
    }

    enum HeaderButton {
        static let size: CGFloat = 44
        static let fontSize: CGFloat = 20
        static let foregroundOpacity: Double = 0.6

        static let font: Font = .system(size: fontSize, weight: .medium)
        static let foregroundStyle = Color.black.opacity(foregroundOpacity)
    }

    enum CompactPlayer {
        static let height: CGFloat = 106
        static let pausedHeight: CGFloat = 86
        static let bottomPadding: CGFloat = 20

        static func height(isPlaying: Bool) -> CGFloat {
            isPlaying ? height : pausedHeight
        }
    }

    enum UserDefaultsKey {
        static let playlistID: String = "UserDefaultsPlaylistIdKey"
    }

    enum AppColor {
        static let defaultBackground = Color(hex: 0xFCFCFC)
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
