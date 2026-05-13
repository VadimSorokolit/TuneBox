//
//  NetworkService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import Foundation
import Moya

enum TrackDownloadNotificationUserInfoKey {
    static let trackID = "trackID"
    static let totalBytesWritten = "totalBytesWritten"
    static let totalBytesExpectedToWrite = "totalBytesExpectedToWrite"
}

protocol NetworkServicing: AnyObject {
    func getTracksByGenre(genre: String?, page: Int, perPage: Int) async throws -> [Track]
    func getPopularTracks(page: Int, perPage: Int) async throws -> [Track]
    func searchTracks(query: String, page: Int, perPage: Int) async throws -> [Track]
    func downloadTrack(_ track: Track) async throws -> URL
    func startDownload(_ track: Track) async throws
    func pauseDownload(trackID: String) async
    func resumeDownload(trackID: String) async throws
    func cancelDownload(trackID: String) async
}

final class NetworkService: NSObject, NetworkServicing {

    // MARK: - Methods. Public

    func getTracksByGenre(genre: String?, page: Int, perPage: Int) async throws -> [Track] {
        do {
            let response = try await self.requestHandler(.getTracksByGenre(genre: genre, page: page, perPage: perPage))
            let decoded = try self.decodeResponse(TracksResponse.self, from: response)

            return await self.enrichTracksWithSize(decoded.results)
        } catch {
            throw APIError.from(error)
        }
    }

    func getPopularTracks(page: Int, perPage: Int) async throws -> [Track] {
        do {
            let response = try await self.requestHandler(.getPopularTracks(page: page, perPage: perPage))
            let decoded = try self.decodeResponse(TracksResponse.self, from: response)

            return await self.enrichTracksWithSize(decoded.results)
        } catch {
            throw APIError.from(error)
        }
    }

    func searchTracks(query: String, page: Int, perPage: Int) async throws -> [Track] {
        do {
            let response = try await self.requestHandler(.searchTracks(query: query, page: page, perPage: perPage))
            let decoded = try self.decodeResponse(TracksResponse.self, from: response)

            return await self.enrichTracksWithSize(decoded.results)
        } catch {
            throw APIError.from(error)
        }
    }

    func downloadTrack(_ track: Track) async throws -> URL {
        guard let remoteURL = track.downloadURL else {
            throw APIError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            Swift.Task { [weak self] in
                guard let self else {
                    continuation.resume(throwing: APIError.unknown)
                    return
                }

                await self.downloadStore.setContinuation(
                    continuation,
                    for: track.id
                )

                do {
                    try self.startDownload(track, remoteURL: remoteURL)
                } catch {
                    await self.downloadStore.removeContinuation(for: track.id)
                    continuation.resume(throwing: APIError.from(error))
                }
            }
        }
    }

    func startDownload(_ track: Track) async throws {
        guard let remoteURL = track.downloadURL else {
            throw APIError.invalidURL
        }

        do {
            try self.startDownload(track, remoteURL: remoteURL)
        } catch {
            throw APIError.from(error)
        }
    }

    func pauseDownload(trackID: String) async {
        guard let task = await self.downloadStore.task(for: trackID) else {
            return
        }

        await self.downloadStore.markPauseRequested(for: trackID)
        let data: Data? = await withCheckedContinuation { continuation in
            task.cancel { resumeData in
                continuation.resume(returning: resumeData)
            }
        }
        await self.downloadStore.saveResumeData(data, for: trackID)
        await self.downloadStore.clearTask(for: trackID)
    }

    func resumeDownload(trackID: String) async throws {
        guard let resumeData = await self.downloadStore.resumeData(for: trackID) else {
            throw APIError.server("No paused download for track \(trackID)")
        }

        let task = self.urlSession.downloadTask(withResumeData: resumeData)
        task.taskDescription = trackID
        await self.downloadStore.storeTask(task, for: trackID)
        await self.downloadStore.clearResumeData(for: trackID)

        task.resume()
    }

    func cancelDownload(trackID: String) async {
        guard let task = await self.downloadStore.task(for: trackID) else {
            return
        }

        task.cancel()
        await self.downloadStore.clearTask(for: trackID)
        await self.downloadStore.clearResumeData(for: trackID)

        if let continuation = await self.downloadStore.takeContinuation(for: trackID) {
            continuation.resume(throwing: APIError.network(URLError(.cancelled)))
        }
    }

    private func getTrackSize(id: Int) async throws -> Int {
        do {
            let response = try await self.requestHandler(.getTrackSize(id: id))

            guard (200 ... 299).contains(response.statusCode) else {
                throw APIError.serverStatusCode(response.statusCode)
            }

            guard let contentLength = response.response?.value(forHTTPHeaderField: Constants.trackContentLengthHeader) else {
                throw APIError.missingContentLength
            }

            guard let trackSize = Int(contentLength) else {
                throw APIError.invalidContentLength
            }

            return trackSize
        } catch {
            throw APIError.from(error)
        }
    }

    // MARK: - Initializer

    init(provider: MoyaProvider<TuneBoxRouter>) {
        self.requestHandler = { target in
            try await provider.request(target)
        }
        super.init()
    }

    init(requestHandler: @escaping (TuneBoxRouter) async throws -> Response) {
        self.requestHandler = requestHandler
        super.init()
    }

    // MARK: - Properties. Private

    private enum Constants {
        static let successStatus = "success"
        static let trackContentLengthHeader = "Content-Length"
    }

    private var requestHandler: (TuneBoxRouter) async throws -> Response

    private lazy var urlSession: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    private let downloadStore = DownloadStore()

    // MARK: - Methods. Private

    private func enrichTracksWithSize(_ tracks: [Track]) async -> [Track] {
        await withTaskGroup(of: (Int, Int?).self) { group in
            for (index, track) in tracks.enumerated() {
                group.addTask { [weak self] in
                    guard
                        let self,
                        let trackID = Int(track.id)
                    else {
                        return (index, nil)
                    }

                    do {
                        let size = try await self.getTrackSize(id: trackID)
                        return (index, size)
                    } catch {
                        return (index, nil)
                    }
                }
            }

            var trackSizes = Array(repeating: Optional<Int>.none, count: tracks.count)
            for await (index, size) in group {
                trackSizes[index] = size
            }

            return tracks.enumerated().map { index, track in
                var updatedTrack = track
                updatedTrack.size = trackSizes[index]
                return updatedTrack
            }
        }
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from response: Response) throws -> T {
        let decoded = try response.map(T.self)

        if let response = decoded as? TracksResponse {
            guard response.headers.status == Constants.successStatus else {
                throw APIError.server(
                    response.headers.errorMessage ?? APIError.unknown.localizedDescription
                )
            }
        }

        return decoded
    }

    private func startDownload(_ track: Track, remoteURL: URL) throws {
        let task = self.urlSession.downloadTask(with: remoteURL)
        task.taskDescription = track.id
        Swift.Task {
            await self.downloadStore.storeTask(task, for: track.id)
        }

        task.resume()
    }

    private func moveDownloadedFile(from temporaryURL: URL, trackID: String) throws -> URL {
        let destinationDirectory = try GlobalConstants.makeTracksDirectoryURL()

        let destinationURL = destinationDirectory
            .appendingPathComponent("\(GlobalConstants.downloadedFilePrefix)\(trackID)")
            .appendingPathExtension(GlobalConstants.audioFileExtension)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }
}

extension NetworkService: URLSessionDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let trackID = downloadTask.taskDescription else {
            return
        }

        NotificationCenter.default.post(
            name: .trackDownloadProgress,
            object: nil,
            userInfo: [
                TrackDownloadNotificationUserInfoKey.trackID: trackID,
                TrackDownloadNotificationUserInfoKey.totalBytesWritten: totalBytesWritten,
                TrackDownloadNotificationUserInfoKey.totalBytesExpectedToWrite: totalBytesExpectedToWrite
            ]
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let trackID = downloadTask.taskDescription else {
            return
        }

        let result: Result<URL, Error>
        do {
            let destinationURL = try self.moveDownloadedFile(
                from: location,
                trackID: trackID
            )
            result = .success(destinationURL)
            NotificationCenter.default.post(
                name: .trackDownloadDidFinish,
                object: nil,
                userInfo: [
                    "trackID": trackID,
                    "url": destinationURL
                ]
            )
        } catch {
            result = .failure(error)
        }

        Swift.Task { [weak self] in
            guard let self else { return }
            guard let continuation = await self.downloadStore.takeContinuation(for: trackID) else {
                return
            }

            switch result {
                case .success(let destinationURL):
                    continuation.resume(returning: destinationURL)
                case .failure(let error):
                    continuation.resume(throwing: APIError.from(error))
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        Swift.Task { [weak self] in
            guard let self else { return }
            guard let trackID = await self.downloadStore.trackID(for: task) else {
                return
            }

            await self.downloadStore.clearTask(for: trackID)

            guard let error else {
                return
            }

            let isPaused = await self.downloadStore.consumePauseRequested(for: trackID)
            if isPaused {
                return
            }

            if let continuation = await self.downloadStore.takeContinuation(for: trackID) {
                continuation.resume(throwing: APIError.from(error))
            }
        }
    }

}

private actor DownloadStore {
    private var tasksByTrackID: [String: URLSessionDownloadTask] = [:]
    private var trackIDByTaskIdentifier: [Int: String] = [:]
    private var resumeDataByTrackID: [String: Data] = [:]
    private var continuationsByTrackID: [String: CheckedContinuation<URL, Error>] = [:]
    private var pauseRequestedTrackIDs: Set<String> = []

    func storeTask(_ task: URLSessionDownloadTask, for trackID: String) {
        self.tasksByTrackID[trackID] = task
        self.trackIDByTaskIdentifier[task.taskIdentifier] = trackID
    }

    func task(for trackID: String) -> URLSessionDownloadTask? {
        self.tasksByTrackID[trackID]
    }

    func trackID(for task: URLSessionTask) -> String? {
        self.trackIDByTaskIdentifier[task.taskIdentifier]
    }

    func clearTask(for trackID: String) {
        if let task = self.tasksByTrackID.removeValue(forKey: trackID) {
            self.trackIDByTaskIdentifier.removeValue(forKey: task.taskIdentifier)
        }
    }

    func saveResumeData(_ data: Data?, for trackID: String) {
        if let data {
            self.resumeDataByTrackID[trackID] = data
        }
    }

    func resumeData(for trackID: String) -> Data? {
        self.resumeDataByTrackID[trackID]
    }

    func clearResumeData(for trackID: String) {
        self.resumeDataByTrackID.removeValue(forKey: trackID)
    }

    func setContinuation(_ continuation: CheckedContinuation<URL, Error>, for trackID: String) {
        self.continuationsByTrackID[trackID] = continuation
    }

    func takeContinuation(for trackID: String) -> CheckedContinuation<URL, Error>? {
        self.continuationsByTrackID.removeValue(forKey: trackID)
    }

    func removeContinuation(for trackID: String) {
        self.continuationsByTrackID.removeValue(forKey: trackID)
    }

    func markPauseRequested(for trackID: String) {
        self.pauseRequestedTrackIDs.insert(trackID)
    }

    func consumePauseRequested(for trackID: String) -> Bool {
        self.pauseRequestedTrackIDs.remove(trackID) != nil
    }
}
