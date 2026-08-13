//
//  NetworkServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation

protocol JamendoServicing: AnyObject {
    func getTracksByGenre(genre: String?, limit: Int, offset: Int) async throws -> [TrackDTO]
    func getPopularTracks(limit: Int, offset: Int) async throws -> [TrackDTO]
    func searchTracks(query: String, limit: Int, offset: Int) async throws -> [TrackDTO]
    func startDownload(_ track: TrackEntity) async throws
    func stopDownload(trackId: String) async
    func resumeDownload(trackId: String) async throws
    func cancelDownload(trackID: String) async
    func cancelAllDownloads() async
    func restoreDownloadSession() async
    func activeDownloadTrackIDs() async -> Set<String>
    func runningDownloadTrackIDs() async -> Set<String>
    func waitForPendingCancellations(timeout: TimeInterval) async
    func snapshotResumeDataForRelaunch() async
    func hasPersistedResumeData(trackId: String) async -> Bool
    func clearPersistedResumeData(trackId: String)
    func setBackgroundCompletionHandler(_ handler: @escaping () -> Void)
}
