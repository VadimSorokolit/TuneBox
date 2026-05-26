//
//  FileManagerServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation

protocol FileManagerServicing: AnyObject {
    func getFreeStorage() -> Double?
    func checkEnoughFreeStorage(requiredGB: Double) throws
    func getTracksFolderURL() throws -> URL
    func getDirectorySizeInBytes() throws -> Int64
    func getDirectorySizeInMB() async throws -> Double
    func deleteDownloadedTrack(id: String) throws
    func downloadedTrackExists(id: String) -> Bool
    func clearStorage() throws
}
