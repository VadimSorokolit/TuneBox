//
//  NetworkService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import Foundation
import Moya

protocol NetworkServicing: AnyObject {
//    func getTracksByGenre(genre: String, page: Int) async throws -> [Track]
    func getPopularTracks(page: Int, perPage: Int) async throws -> [Track]
//    func searchTracks(query: String, page: Int, perPage: Int) async throws -> [Track]
    func getTrackSize(id: Int) async throws -> Int
}

class NetworkService: NetworkServicing {

    // MARK: - Methods. Public

    func getPopularTracks(page: Int, perPage: Int) async throws -> [Track] {
        do {
            let response = try await provider.request(
                .getPopularTracks(
                    page: page,
                    perPage: perPage
                )
            )

            let decoded = try response.map(TracksResponse.self)

            guard decoded.headers.status == "success" else {
                throw APIError.server(decoded.headers.errorMessage)
            }

            return decoded.results
        } catch {
            throw APIError.from(error)
        }
    }

    func getTrackSize(id: Int) async throws -> Int {
        do {
            let response = try await provider.request(.getTrackSize(id: id))

            guard (200 ... 299).contains(response.statusCode) else {
                throw APIError.serverStatusCode(response.statusCode)
            }

            guard let contentLength = response.response?.value(forHTTPHeaderField: "Content-Length") else {
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

    private let provider: MoyaProvider<TuneBoxRouter>
}
