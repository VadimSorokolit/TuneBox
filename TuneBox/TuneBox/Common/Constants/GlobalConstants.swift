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

    private static var tracksDirectoryURL: URL {
        get throws {
            guard let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw FileError.missingDirectory
            }

            let url = base.appendingPathComponent("Tracks", isDirectory: true)

            AppLogger.storage.debug(
                "Tracks directory URL resolved: \(url.path)"
            )

            return url
        }
    }

    static func makeTracksDirectoryURL() throws -> URL {
        let tracksDirectoryURL = try Self.tracksDirectoryURL

        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(
            atPath: tracksDirectoryURL.path,
            isDirectory: &isDirectory
        ) {
            guard isDirectory.boolValue else {
                AppLogger.storage.error(
                    "Tracks path exists but is not directory: \(tracksDirectoryURL.path)"
                )

                throw FileError.missingDirectory
            }

            AppLogger.storage.debug(
                "Tracks directory already exists: \(tracksDirectoryURL.path)"
            )

            return tracksDirectoryURL
        }

        try FileManager.default.createDirectory(
            at: tracksDirectoryURL,
            withIntermediateDirectories: true
        )

        AppLogger.storage.debug(
            "Tracks directory created: \(tracksDirectoryURL.path)"
        )

        return tracksDirectoryURL
    }
}
