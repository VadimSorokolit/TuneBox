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
    }

    enum UserDefaultsKey {
        static let playlistID: String = "UserDefaultsPlaylistIdKey"
    }

    enum AppColor {
        static let defaultBackground = SwiftUI.Color(hex: 0xFCFCFC)
    }
}
