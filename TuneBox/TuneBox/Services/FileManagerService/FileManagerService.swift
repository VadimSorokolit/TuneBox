//
//  FileManagerService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.05.2026.
//

import Foundation

final class FileManagerService: FileManagerServicing {

    // MARK: - Methods. Public

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

    func getTracksFolderURL() throws -> URL {
        try self.makeTracksDirectoryIfNeeded()
    }

    func getDirectorySizeInMB() throws -> Double {
        let url = try self.getTracksFolderURL()
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

    func makeDownloadedTrackURL(id: String) throws -> URL {
        let tracksDirectory = try self.makeTracksDirectoryIfNeeded()

        return tracksDirectory
            .appendingPathComponent("\(id)")
            .appendingPathExtension(AudioFileExtension.mp3.rawValue)
    }

    func deleteDownloadedTrack(id: String) throws {
        let trackURL = try self.makeDownloadedTrackURL(id: id)

        guard FileManager.default.fileExists(atPath: trackURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: trackURL)
    }

    func downloadedTrackExists(id: String) -> Bool {
        guard let trackURL = try? self.makeDownloadedTrackURL(id: id) else {
            return false
        }

        return FileManager.default.fileExists(atPath: trackURL.path)
    }

    func clearStorage() throws {
        let tracksDirectory = try self.makeTracksDirectoryIfNeeded()
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
    }

    private var cachedTracksDirectoryURL: URL?

    // MARK: - Methods. Private

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

    private func makeTracksDirectoryIfNeeded() throws -> URL {
        if let url = self.cachedTracksDirectoryURL {
            AppLogger.storage.debug("Using cached tracks directory URL: \(url.path)")
            return url
        }

        let url = try GlobalConstants.makeTracksDirectoryURL()
        self.cachedTracksDirectoryURL = url

        AppLogger.storage.debug("Cached tracks directory URL: \(url.path)")

        return url
    }
}
