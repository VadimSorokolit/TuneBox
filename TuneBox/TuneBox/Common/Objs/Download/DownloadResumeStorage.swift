//
//  DownloadResumeStorage.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 21.05.2026.
//

import Foundation

private enum DownloadResumeStorageError: Error {
    case missingDirectory
}

enum DownloadResumeStorage {
    private static let resumeDirectoryName = "ResumeData"

    static func save(_ data: Data, for trackID: String) throws {
        let fileURL = try self.resumeFileURL(for: trackID)
        try data.write(to: fileURL, options: .atomic)
    }

    static func load(for trackID: String) -> Data? {
        guard let fileURL = try? self.resumeFileURL(for: trackID) else {
            return nil
        }

        return try? Data(contentsOf: fileURL)
    }

    private static func resumeFileURL(for trackID: String) throws -> URL {
        let directoryURL = try self.makeResumeDirectoryURL()

        return directoryURL.appendingPathComponent(trackID, isDirectory: false)
    }

    static func remove(for trackID: String) {
        guard let fileURL = try? self.resumeFileURL(for: trackID) else {
            return
        }

        try? FileManager.default.removeItem(at: fileURL)
    }

    static func removeAll() {
        guard let directoryURL = try? self.makeResumeDirectoryURL() else {
            return
        }

        try? FileManager.default.removeItem(at: directoryURL)
    }

    private static func makeResumeDirectoryURL() throws -> URL {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw DownloadResumeStorageError.missingDirectory
        }

        let directoryURL = base.appendingPathComponent(self.resumeDirectoryName, isDirectory: true)

        if FileManager.default.fileExists(atPath: directoryURL.path) == false {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }

        return directoryURL
    }
}
