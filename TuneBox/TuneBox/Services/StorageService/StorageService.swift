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

    // MARK: - Properties. Private

    private enum Constants {
        static let bytesInGigabyte: Double = 1e9
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
}
