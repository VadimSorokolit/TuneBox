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
    static let tracksDirectory = "Tracks"
    static let audioFileExtension = "mp3"
    static let downloadedFilePrefix = "track"

    static func makeTracksDirectoryURL() throws -> URL {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw FileError.missingDirectory
        }

        let tracksURL = base.appendingPathComponent(self.tracksDirectory, isDirectory: true)

        if !FileManager.default.fileExists(atPath: tracksURL.path) {
            try FileManager.default.createDirectory(
                at: tracksURL,
                withIntermediateDirectories: true
            )
        }
        
        print(tracksURL)
        return tracksURL
    }
}
