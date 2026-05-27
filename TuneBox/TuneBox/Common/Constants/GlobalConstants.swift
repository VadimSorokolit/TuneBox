//
//  GlobalConstants.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.05.2026.
//

private enum FileError: Error {
    case missingDirectory
}

import Foundation

enum GlobalConstants {
    static let bytesInGigabyte: Double = 1e9
    static let trackExtension: AudioFileExtension = .mp3
    static let downloadedFilePrefix = "track"
}
