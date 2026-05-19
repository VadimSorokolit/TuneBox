//
//  TuneBoxRouter.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import Foundation
import os
import Moya

/**
 - Note:
 API Docs: - https://developer.jamendo.com/v3.0/docs
 */

private struct Constants {
    struct API {
        static let baseURL = "https://api.jamendo.com/v3.0"
        static let storageURL = "https://prod-1.storage.jamendo.com"
        static let defaultPath = "/tracks"
        static let downloadPath = "/download/track/%d/mp32/"
    }

    struct Params {
        static let clientId = "client_id"
        static let tags = "tags"
        static let order = "order"
        static let search = "search"
        static let limit = "limit"
        static let offset = "offset"
    }

    struct Values {
        static let popularityTotal = "popularity_total"
    }

    static let mockAPIKey = "88888888"
    static let fallbackBaseURL = "google.com"
    static let apiKeyEnvName = "APIKey"
    static let invalidURLMessage = "Invalid baseURL:"
    static let warningMessage = "Using mock API key"

    static var apiKey: String {
        if let key = ProcessInfo.processInfo.environment[Constants.apiKeyEnvName] {
            return key
        } else {
            AppLogger.api.warning("\(Constants.warningMessage)")
            return Constants.mockAPIKey
        }
    }
}

enum TuneBoxRouter {
    case getTracksByGenre(genre: String?, page: Int, perPage: Int)
    case getPopularTracks(page: Int, perPage: Int)
    case getTrackSize(id: Int)
    case searchTracks(query: String, page: Int, perPage: Int)
}

// MARK: - TargetType Protocol

extension TuneBoxRouter: TargetType {

    private typealias API = Constants.API
    private typealias Params = Constants.Params

    private var params: [String: Any] {
        switch self {
            case let .getTracksByGenre(genre, page, perPage):
                let pagination = makePagination(
                    page: page,
                    perPage: perPage
                )

                var params: [String: Any] = [
                    Params.clientId: Constants.apiKey,
                    Params.limit: pagination.limit,
                    Params.offset: pagination.offset
                ]

                if let genre, !genre.isEmpty {
                    params[Params.tags] = genre
                }

                return params

            case let .getPopularTracks(page, perPage):
                let pagination = makePagination(
                    page: page,
                    perPage: perPage
                )

                return [
                    Params.clientId: Constants.apiKey,
                    Params.order: Constants.Values.popularityTotal,
                    Params.limit: pagination.limit,
                    Params.offset: pagination.offset
                ]

            case let .searchTracks(query, page, perPage):
                let pagination = makePagination(
                    page: page,
                    perPage: perPage
                )

                return [
                    Params.clientId: Constants.apiKey,
                    Params.search: query,
                    Params.limit: pagination.limit,
                    Params.offset: pagination.offset
                ]

            case .getTrackSize:
                return [:]
        }
    }

    private func makePagination(page: Int, perPage: Int) -> (limit: Int, offset: Int) {
        let safePage = max(page, 1)
        let safePerPage = max(perPage, 1)
        let offset = (safePage - 1) * safePerPage

        return (safePerPage, offset)
    }

    var baseURL: URL {
        let urlString: String

        switch self {
            case .getTrackSize:
                urlString = API.storageURL

            default:
                urlString = API.baseURL
        }

        guard let url = URL(string: urlString) ?? URL(string: Constants.fallbackBaseURL) else {
            fatalError("\(Constants.invalidURLMessage) \(urlString)")
        }

        return url
    }

    var path: String {
        switch self {
            case .getTrackSize(let id):
                return String(format: API.downloadPath, id)

            case .getTracksByGenre, .getPopularTracks, .searchTracks:
                return API.defaultPath
        }
    }

    var method: Moya.Method {
        switch self {
            case .getTrackSize:
                return .head

            default:
                return .get
        }
    }

    var task: Task {
        switch self {
            case .getTrackSize:
                return .requestPlain

            default:
                return .requestParameters(
                    parameters: params,
                    encoding: URLEncoding.default
                )
        }
    }

    var headers: [String: String]? {
        nil
    }

}
