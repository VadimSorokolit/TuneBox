//
//  FileManagerService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.05.2026.
//

import Foundation

final class FileManagerService: FileManagerServicing {

    // MARK: - Methods. Public

    static func makeDownloadedTrackURL(id: String) throws -> URL {
        let tracksDirectory = try self.makeTracksDirectoryIfNeeded()

        return tracksDirectory
            .appendingPathComponent("\(Constants.trackPrefix)\(id)")
            .appendingPathExtension(AudioFileExtension.mp3.rawValue)
    }

    static func storeDownloadedFile(from temporaryURL: URL, trackID: String) throws -> URL {
        try Swift.Task.checkCancellation()

        let destinationURL = try FileManagerService.makeDownloadedTrackURL(id: trackID)

        try Swift.Task.checkCancellation()

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try Swift.Task.checkCancellation()

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)

        return destinationURL
    }

    func checkEnoughFreeStorage(requiredGB: Double) throws {
        guard let freeStorage = self.getFreeStorage() else {
            throw AppError.FileManager.unavailable
        }

        guard freeStorage >= requiredGB else {
            throw AppError.FileManager.notEnoughSpace(
                requiredGB: requiredGB,
                availableGB: freeStorage
            )
        }
    }

    func getDirectorySizeInMB() throws -> Double {
        let url = try FileManagerService.makeTracksDirectoryIfNeeded()
        let directoryURL = try self.resolveDirectoryURL(from: url)

        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values.isRegularFile == true {
                totalSize += Int64(values.fileSize ?? 0)
            }
        }

        let bytes = totalSize

        return Double(bytes) / Constants.bytesInMegabyte
    }

    func deleteDownloadedTrack(id: String) throws {
        let trackURL = try FileManagerService.makeDownloadedTrackURL(id: id)

        guard FileManager.default.fileExists(atPath: trackURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: trackURL)
    }

    func downloadedTrackExists(id: String) -> Bool {
        guard let trackURL = try? FileManagerService.makeDownloadedTrackURL(id: id) else {
            return false
        }

        return FileManager.default.fileExists(atPath: trackURL.path)
    }

    func clearStorage() throws {
        let tracksDirectory = try FileManagerService.makeTracksDirectoryIfNeeded()
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: tracksDirectory,
            includingPropertiesForKeys: nil
        )

        for fileURL in fileURLs {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Properties. Private

    private enum Constants {
        static let bytesInMegabyte: Double = 1e6
        static let directoryName: String = "Tracks"
        static let trackPrefix: String = "track"
    }

    private static var cachedTracksDirectoryURL: URL?

    // MARK: - Methods. Private

    private static func makeTracksDirectoryIfNeeded() throws -> URL {
        if let url = FileManagerService.cachedTracksDirectoryURL {
            return url
        }

        let url = try self.makeTracksDirectoryURL()
        FileManagerService.cachedTracksDirectoryURL = url

        AppLogger.storage.debug("Cached tracks directory URL: \(url.path)")

        return url
    }

    func getFreeStorage() -> Double? {
        guard
            let attributes = try? FileManager.default.attributesOfFileSystem(
                forPath: NSHomeDirectory()
            ),
            let freeSize = attributes[.systemFreeSize] as? NSNumber
        else {
            return nil
        }

        let bytes = freeSize.doubleValue
        let gigabytes = bytes / GlobalConstants.bytesInGigabyte

        return gigabytes
    }

    private func resolveDirectoryURL(from url: URL) throws -> URL {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        return values.isDirectory == true ? url : url.deletingLastPathComponent()
    }

    private static func makeTracksDirectoryURL() throws -> URL {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw AppError.File.missingDirectory
        }

        let tracksDirectoryURL = base.appendingPathComponent(
            Constants.directoryName,
            isDirectory: true
        )

        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(
            atPath: tracksDirectoryURL.path,
            isDirectory: &isDirectory
        ) {
            guard isDirectory.boolValue else {
                AppLogger.storage.error(
                    "Tracks path exists but is not directory: \(tracksDirectoryURL.path)"
                )

                throw AppError.File.missingDirectory
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
