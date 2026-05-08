//
//  StorageService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.05.2026.
//

import Foundation

enum StorageError: LocalizedError {
    case unavailable
    case notEnoughSpace(requiredGB: Double, availableGB: Double)

    var errorDescription: String? {
        switch self {
            case .unavailable:
                return "Unable to determine available storage."
            case .notEnoughSpace(let requiredGB, let availableGB):
                return "Not enough free space. Required: \(requiredGB) GB, available: \(availableGB) GB."
        }
    }
}

protocol StorageServicing {
    func getFreeStorage() -> Double?
    func checkEnoughFreeStorage(requiredGB: Double) throws
    func getDirectorySizeInBytes(from url: URL) throws -> Int64
    func getDirectorySizeInMB(from url: URL) throws -> Double
}

final class StorageService: StorageServicing {

    // MARK: Methods. Public

    func checkEnoughFreeStorage(requiredGB: Double) throws {
        guard let freeStorage = self.getFreeStorage() else {
            throw StorageError.unavailable
        }

        guard freeStorage >= requiredGB else {
            throw StorageError.notEnoughSpace(
                requiredGB: requiredGB,
                availableGB: freeStorage
            )
        }
    }

    func getDirectorySizeInBytes(from url: URL) throws -> Int64 {
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

        return totalSize
    }

    func getDirectorySizeInMB(from url: URL) throws -> Double {
        let bytes = try self.getDirectorySizeInBytes(from: url)
        return Double(bytes) / Constants.bytesInMegabyte
    }

    // MARK: - Properties. Private

    private enum Constants {
        static let bytesInGigabyte: Double = 1e9
        static let bytesInMegabyte: Double = 1e6
    }

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
        let gigabytes = bytes / Constants.bytesInGigabyte

        return gigabytes
    }

    private func resolveDirectoryURL(from url: URL) throws -> URL {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        return values.isDirectory == true ? url : url.deletingLastPathComponent()
    }
}
