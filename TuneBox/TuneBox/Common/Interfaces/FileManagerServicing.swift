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
    func getDirectorySizeInMB() async throws -> Double
    func downloadedTrackExists(id: String) -> Bool
    func deleteDownloadedTrack(id: String) throws
    func clearStorage() throws
    static func makeDownloadedTrackURL(id: String) throws -> URL
    static func storeDownloadedFile(from temporaryURL: URL, trackID: String) throws -> URL
}
