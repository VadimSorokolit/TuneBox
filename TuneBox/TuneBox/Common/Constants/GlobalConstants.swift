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
    static let bytesInMegabyte: Double = 1e6
    static let trackExtension: AudioFileExtension = .mp3
    static let tracksDirectory = "Tracks"
    static let downloadedFilePrefix = "track"

    static func makeTracksDirectoryURL() throws -> URL {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw FileError.missingDirectory
        }

        let tracksURL = base.appendingPathComponent(self.tracksDirectory, isDirectory: true)

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: tracksURL.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw FileError.missingDirectory
            }

            AppLogger.storage.debug("Tracks directory is already exists: \(tracksURL.path)")
            return tracksURL
        }

        try FileManager.default.createDirectory(
            at: tracksURL,
            withIntermediateDirectories: true
        )

        AppLogger.storage.debug("Tracks directory created: \(tracksURL.path)")
        return tracksURL
    }
}
