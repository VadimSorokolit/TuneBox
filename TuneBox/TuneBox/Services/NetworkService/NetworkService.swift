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
    static let destinationURL = "url"
    static let error = "error"
}

final class NetworkService: NSObject, NetworkServicing {

    // MARK: - Methods. Public

    func getTracksByGenre(genre: String?, limit: Int, offset: Int) async throws -> [TrackDTO] {
        do {
            let response = try await self.requestHandler(.getTracksByGenre(genre: genre, limit: limit, offset: offset))
            let decoded = try self.decodeResponse(TracksResponse.self, from: response)

            return await self.updateTracksWithSizes(decoded.results)
        } catch {
            throw AppError.API.from(error)
        }
    }

    func getPopularTracks(limit: Int, offset: Int) async throws -> [TrackDTO] {
        do {
            let response = try await self.requestHandler(.getPopularTracks(limit: limit, offset: offset))
            let decoded = try self.decodeResponse(TracksResponse.self, from: response)

            return await self.updateTracksWithSizes(decoded.results)
        } catch {
            throw AppError.API.from(error)
        }
    }

    func searchTracks(query: String, limit: Int, offset: Int) async throws -> [TrackDTO] {
        do {
            let response = try await self.requestHandler(.searchTracks(query: query, limit: limit, offset: offset))
            let decoded = try self.decodeResponse(TracksResponse.self, from: response)

            return await self.updateTracksWithSizes(decoded.results)
        } catch {
            throw AppError.API.from(error)
        }
    }

    @MainActor
    func startDownload(_ track: TrackEntity) async throws {
        guard let remoteURL = track.downloadURL else {
            throw AppError.API.invalidURL
        }

        do {
            try await self.startDownload(trackID: track.id, remoteURL: remoteURL)
        } catch {
            throw AppError.API.from(error)
        }
    }

    func stopDownload(trackId: String) async {
        guard let task = await self.downloadStore.task(for: trackId) else {
            return
        }

        await self.downloadStore.stopRequested(for: trackId)
        let data: Data? = await withCheckedContinuation { continuation in
            task.cancel { resumeData in
                continuation.resume(returning: resumeData)
            }
        }
        await self.downloadStore.saveResumeData(data, for: trackId)
        self.persistResumeData(data, for: trackId)
        await self.downloadStore.clearTask(for: trackId)
    }

    func resumeDownload(trackId: String) async throws {
        guard let resumeData = await self.resolveResumeData(for: trackId) else {
            throw AppError.API.server("No paused download for track \(trackId)")
        }

        let task = self.urlSession.downloadTask(withResumeData: resumeData)
        task.taskDescription = trackId

        await self.downloadStore.storeTask(task, for: trackId)
        await self.downloadStore.clearResumeData(for: trackId)

        DownloadResumeStorage.remove(for: trackId)

        task.resume()
    }

    func cancelDownload(trackID: String) async {
        guard let task = await self.downloadStore.task(for: trackID) else {
            return
        }

        task.cancel()

        await self.downloadStore.clearTask(for: trackID)
        await self.downloadStore.clearResumeData(for: trackID)

        DownloadResumeStorage.remove(for: trackID)
    }

    func cancelAllDownloads() async {
        let trackIDs = await self.downloadStore.activeTrackIDs()

        for trackID in trackIDs {
            await self.cancelDownload(trackID: trackID)
        }
    }

    func restoreDownloadSession() async {
        let tasks = await withCheckedContinuation { continuation in
            self.urlSession.getAllTasks { tasks in
                continuation.resume(returning: tasks)
            }
        }

        for task in tasks {
            guard
                let downloadTask = task as? URLSessionDownloadTask,
                let trackID = downloadTask.taskDescription
            else {
                continue
            }

            await self.downloadStore.storeTask(downloadTask, for: trackID)

            if downloadTask.state == .running, downloadTask.countOfBytesReceived > 0 {
                NotificationCenter.default.post(
                    name: .trackDownloadProgress,
                    object: nil,
                    userInfo: [
                        TrackDownloadNotificationUserInfoKey.trackID: trackID,
                        TrackDownloadNotificationUserInfoKey.totalBytesWritten: downloadTask.countOfBytesReceived,
                        TrackDownloadNotificationUserInfoKey.totalBytesExpectedToWrite: downloadTask.countOfBytesExpectedToReceive
                    ]
                )
            }
        }
    }

    func activeDownloadTrackIDs() async -> Set<String> {
        await self.downloadStore.activeTrackIDs()
    }

    func runningDownloadTrackIDs() async -> Set<String> {
        let tasks: [URLSessionTask] = await withCheckedContinuation { continuation in
            self.urlSession.getAllTasks { tasks in
                continuation.resume(returning: tasks)
            }
        }

        var running = Set<String>()

        for task in tasks {
            guard
                task is URLSessionDownloadTask,
                let trackID = task.taskDescription,
                task.state == .running || task.state == .suspended
            else {
                continue
            }

            running.insert(trackID)
        }

        return running
    }

    func waitForPendingCancellations(timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        let checkInterval: Duration = .seconds(0.1)

        while Date() < deadline {
            if _Concurrency.Task.isCancelled {
                return
            }

            let tasks: [URLSessionTask] = await withCheckedContinuation { continuation in
                self.urlSession.getAllTasks { tasks in
                    continuation.resume(returning: tasks)
                }
            }

            let hasCancelingTasks = tasks.contains { $0.state == .canceling }

            if hasCancelingTasks == false {
                return
            }

            try? await _Concurrency.Task.sleep(for: checkInterval)
        }
    }

    func snapshotResumeDataForRelaunch() async {
        let trackIDs = await self.downloadStore.activeTrackIDs()

        for trackID in trackIDs {
            guard let task = await self.downloadStore.task(for: trackID) else {
                continue
            }

            await self.downloadStore.relaunchSnapshotRequested(for: trackID)

            let data: Data? = await withCheckedContinuation { continuation in
                task.cancel { resumeData in
                    continuation.resume(returning: resumeData)
                }
            }

            await self.downloadStore.saveResumeData(data, for: trackID)
            self.persistResumeData(data, for: trackID)
            await self.downloadStore.clearTask(for: trackID)
        }
    }

    func hasPersistedResumeData(trackId: String) async -> Bool {
        if await self.downloadStore.resumeData(for: trackId) != nil {
            return true
        }

        return DownloadResumeStorage.load(for: trackId) != nil
    }

    func clearPersistedResumeData(trackId: String) {
        DownloadResumeStorage.remove(for: trackId)
    }

    private func getTrackSize(id: Int) async throws -> Int {
        do {
            let response = try await self.requestHandler(.getTrackSize(id: id))

            guard (200 ... 299).contains(response.statusCode) else {
                throw AppError.API.serverStatusCode(response.statusCode)
            }

            guard let contentLength = response.response?.value(forHTTPHeaderField: Constants.trackContentLengthHeader) else {
                throw AppError.API.missingContentLength
            }

            guard let trackSize = Int(contentLength) else {
                throw AppError.API.invalidContentLength
            }

            return trackSize
        } catch {
            throw AppError.API.from(error)
        }
    }

    func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        self.backgroundCompletionHandler = handler
    }

    // MARK: - Initializer

    init(provider: MoyaProvider<JamendoRouter>) {
        self.requestHandler = { target in
            try await provider.request(target)
        }
        super.init()
    }

    init(requestHandler: @escaping (JamendoRouter) async throws -> Response) {
        self.requestHandler = requestHandler
        super.init()
    }

    // MARK: - Properties. Private

    private enum Constants {
        static let successStatus = "success"
        static let trackContentLengthHeader = "Content-Length"
        static let urlSessionBackgroundIdentifier: String = "com.tunebox.background.downloads"
    }

    private var backgroundCompletionHandler: (() -> Void)?
    private var requestHandler: (JamendoRouter) async throws -> Response

    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.background(
            withIdentifier: Constants.urlSessionBackgroundIdentifier
        )

        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false

        return URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
    }()

    private let downloadStore = DownloadStore()

    // MARK: - Methods. Private

    private func updateTracksWithSizes(_ tracks: [TrackDTO]) async -> [TrackDTO] {
        await withTaskGroup(of: (Int, Int?).self) { group in
            for (index, track) in tracks.enumerated() {
                group.addTask { [weak self] in
                    if _Concurrency.Task.isCancelled {
                        return (index, nil)
                    }

                    guard
                        let self,
                        let trackID = Int(track.id)
                    else {
                        return (index, nil)
                    }

                    do {
                        let size = try await self.getTrackSize(id: trackID)

                        if _Concurrency.Task.isCancelled {
                            return (index, nil)
                        }

                        return (index, size)
                    } catch {
                        return (index, nil)
                    }
                }
            }

            var trackSizes = Array(repeating: Optional<Int>.none, count: tracks.count)

            for await (index, size) in group {
                if _Concurrency.Task.isCancelled {
                    return tracks
                }

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
                throw AppError.API.server(
                    response.headers.errorMessage ?? AppError.API.unknown.localizedDescription
                )
            }
        }

        return decoded
    }

    private func resolveResumeData(for trackId: String) async -> Data? {
        if let resumeData = await self.downloadStore.resumeData(for: trackId) {
            return resumeData
        }

        return DownloadResumeStorage.load(for: trackId)
    }

    private func persistResumeData(_ data: Data?, for trackId: String) {
        guard let data else {
            return
        }

        do {
            try DownloadResumeStorage.save(data, for: trackId)
        } catch {
            AppLogger.transfer.warning("Failed to persist resume data for \(trackId): \(error.localizedDescription)")
        }
    }

    private func startDownload(trackID: String, remoteURL: URL) async throws {
        let task = urlSession.downloadTask(with: remoteURL)
        task.taskDescription = trackID

        await downloadStore.storeTask(task, for: trackID)

        task.resume()
    }
}

extension NetworkService: URLSessionDownloadDelegate {

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        _Concurrency.Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let synchronouslySavedResumeData: Data? = {
            guard let error = error as NSError? else {
                return nil
            }

            guard let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data else {
                return nil
            }

            if let trackID = task.taskDescription {
                self.persistResumeData(resumeData, for: trackID)
            }

            return resumeData
        }()

        _Concurrency.Task { [weak self] in
            guard let self else { return }

            guard let trackID = await self.downloadStore.trackID(for: task) else {
                return
            }

            let isCurrent = await self.downloadStore.isCurrentTask(task, for: trackID)

            if isCurrent {
                await self.downloadStore.clearTask(for: trackID)
            } else {
                await self.downloadStore.clearTaskIdentifierMapping(for: task)
            }

            guard let error else {
                return
            }

            let isPaused = await self.downloadStore.consumePauseRequested(for: trackID)
            let isRelaunchSnapshot = await self.downloadStore.consumeRelaunchSnapshotRequested(for: trackID)

            if isPaused || isRelaunchSnapshot {
                return
            }

            if let resumeData = synchronouslySavedResumeData {
                await self.downloadStore.saveResumeData(resumeData, for: trackID)
            }

            if self.isInterruptionError(error) {
                NotificationCenter.default.post(
                    name: .trackDownloadDidInterrupt,
                    object: nil,
                    userInfo: [
                        TrackDownloadNotificationUserInfoKey.trackID: trackID
                    ]
                )

                return
            }

            NotificationCenter.default.post(
                name: .trackDownloadDidFail,
                object: nil,
                userInfo: [
                    TrackDownloadNotificationUserInfoKey.trackID: trackID,
                    TrackDownloadNotificationUserInfoKey.error: AppError.API.from(error)
                ]
            )
        }
    }

    private func isInterruptionError(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
                case NSURLErrorCancelled,
                     NSURLErrorNetworkConnectionLost,
                     NSURLErrorNotConnectedToInternet,
                     NSURLErrorTimedOut,
                     NSURLErrorBackgroundSessionWasDisconnected,
                     NSURLErrorBackgroundSessionInUseByAnotherProcess:
                    return true

                default:
                    return false
            }
        }

        return false
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let trackID = downloadTask.taskDescription else {
            return
        }

        if let response = downloadTask.response as? HTTPURLResponse,
           !(200 ... 299).contains(response.statusCode) {

            NotificationCenter.default.post(
                name: .trackDownloadDidFail,
                object: nil,
                userInfo: [
                    TrackDownloadNotificationUserInfoKey.trackID: trackID,
                    TrackDownloadNotificationUserInfoKey.error: AppError.API.serverStatusCode(response.statusCode)
                ]
            )

            return
        }

        do {
            let destinationURL = try FileManagerService.storeDownloadedFile(
                from: location,
                trackID: trackID
            )

            DownloadResumeStorage.remove(for: trackID)

            NotificationCenter.default.post(
                name: .trackDownloadDidFinish,
                object: nil,
                userInfo: [
                    TrackDownloadNotificationUserInfoKey.trackID: trackID,
                    TrackDownloadNotificationUserInfoKey.destinationURL: destinationURL
                ]
            )
        } catch {
            NotificationCenter.default.post(
                name: .trackDownloadDidFail,
                object: nil,
                userInfo: [
                    TrackDownloadNotificationUserInfoKey.trackID: trackID,
                    TrackDownloadNotificationUserInfoKey.error: AppError.API.from(error)
                ]
            )
        }
    }

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

}
