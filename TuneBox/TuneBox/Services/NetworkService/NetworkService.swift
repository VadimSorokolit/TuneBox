//
//  NetworkService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import Foundation
import Moya

protocol NetworkServicing: AnyObject {
    func getTracksByGenre(genre: String?, page: Int, perPage: Int) async throws -> [Track]
    func getPopularTracks(page: Int, perPage: Int) async throws -> [Track]
    func searchTracks(query: String, page: Int, perPage: Int) async throws -> [Track]
    func downloadTrack(_ track: Track) async throws -> URL
}

final class NetworkService: NetworkServicing {

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

        do {
            let (temporaryURL, _) = try await URLSession.shared.download(from: remoteURL)
            let destinationDirectory = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            )[0]
            .appendingPathComponent(GlobalConstants.tracksDirectory)

            if !FileManager.default.fileExists(atPath: destinationDirectory.path) {
                try FileManager.default.createDirectory(
                    at: destinationDirectory,
                    withIntermediateDirectories: true
                )
            }

            let destinationURL = destinationDirectory
                .appendingPathComponent("\(GlobalConstants.downloadedFilePrefix)\(track.id)")
                .appendingPathExtension(GlobalConstants.audioFileExtension)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)

            return destinationURL
        } catch {
            throw APIError.from(error)
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
    }

    init(requestHandler: @escaping (TuneBoxRouter) async throws -> Response) {
        self.requestHandler = requestHandler
    }

    // MARK: - Properties. Private

    private enum Constants {
        static let successStatus = "success"
        static let trackContentLengthHeader = "Content-Length"
    }

    private let requestHandler: (TuneBoxRouter) async throws -> Response

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
}
