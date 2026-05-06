//
//  TuneBoxRouter.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import Foundation
import os
import Alamofire
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
        static let clientID = "client_id"
        static let tags = "tags"
        static let limit = "limit"
        static let order = "order"
        static let search = "search"
        static let offset = "offset"
    }

    struct Values {
        static let popularityTotal = "popularity_total"
    }

    static let mockAPIKey = "88888888"
    static let googleBaseURL = "google.com"
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
    case getTracksByGenre(genre: String, limit: Int)
    case getPopularTracks(limit: Int)
    case getSongSize(id: Int)
    case searchTracks(query: String, limit: Int, offset: Int)
}

// MARK: - TargetType Protocol

extension TuneBoxRouter: TargetType {

    private typealias API = Constants.API
    private typealias Params = Constants.Params

    private var params: [String: Any] {
        switch self {
            case let .getTracksByGenre(genre, limit):
                return [
                    Params.clientID: Constants.apiKey,
                    Params.tags: genre,
                    Params.limit: limit
                ]

            case let .getPopularTracks(limit):
                return [
                    Params.clientID: Constants.apiKey,
                    Params.order: Constants.Values.popularityTotal,
                    Params.limit: limit
                ]

            case let .searchTracks(query, limit, offset):
                return [
                    Params.clientID: Constants.apiKey,
                    Params.search: query,
                    Params.limit: limit,
                    Params.offset: offset
                ]

            case .getSongSize:
                return [:]
        }
    }

    var baseURL: URL {
        let urlString: String

        switch self {
            case .getSongSize:
                urlString = API.storageURL

            default:
                urlString = API.baseURL
        }

        guard let url = URL(string: urlString) ?? URL(string: Constants.googleBaseURL) else {
            fatalError("\(Constants.invalidURLMessage) \(urlString)")
        }

        return url
    }

    var path: String {
        switch self {
            case .getSongSize(let id):
                return String(format: API.downloadPath, id)

            case .getTracksByGenre, .getPopularTracks, .searchTracks:
                return API.defaultPath
        }
    }

    var method: Moya.Method {
        switch self {
            case .getSongSize:
                return .head

            default:
                return .get
        }
    }

    var task: Task {
        switch self {
            case .getSongSize:
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
