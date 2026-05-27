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
    func getDirectorySizeInMB() async throws -> Double
    func downloadedTrackExists(id: String) -> Bool
    static func makeTracksDirectoryIfNeeded() throws -> URL
    func deleteDownloadedTrack(id: String) throws
    func clearStorage() throws
}
