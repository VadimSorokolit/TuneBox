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
    func getTrackSize(id: Int) async throws -> Int
}

class NetworkService: NetworkServicing {

    // MARK: - Methods. Public

    func getTracksByGenre(genre: String?, page: Int, perPage: Int) async throws -> [Track] {
        do {
            let response = try await self.provider.request(.getTracksByGenre(genre: genre, page: page, perPage: perPage))
            let decoded: TracksResponse = try self.decodeResponse(TracksResponse.self, from: response)

            return decoded.results
        } catch {
            throw APIError.from(error)
        }
    }

    func getPopularTracks(page: Int, perPage: Int) async throws -> [Track] {
        do {
            let response = try await self.provider.request(.getPopularTracks(page: page, perPage: perPage))

            let decoded = try response.map(TracksResponse.self)

            guard decoded.headers.status == "success" else {
                throw APIError.server(decoded.headers.errorMessage ?? "Unknown server error")
            }

            return decoded.results
        } catch {
            throw APIError.from(error)
        }
    }

    func searchTracks(query: String, page: Int, perPage: Int) async throws -> [Track] {
        do {
            let response = try await self.provider.request(.searchTracks(query: query, page: page, perPage: perPage))
            let decoded = try self.decodeResponse(TracksResponse.self, from: response)

            return decoded.results
        } catch {
            throw APIError.from(error)
        }
    }

    func getTrackSize(id: Int) async throws -> Int {
        do {
            let response = try await self.provider.request(.getTrackSize(id: id))

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
        self.provider = provider
    }

    // MARK: - Properties. Private

    private enum Constants {
        static let successStatus = "success"
        static let trackContentLengthHeader = "Content-Length"
    }

    private let provider: MoyaProvider<TuneBoxRouter>

    // MARK: - Methods. Private

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
