//
//  TuneBoxRouter.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import Foundation
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
    static let сlientIDKey = "JAMENDO_CLIENT_ID"
    static let invalidURLMessage = "Invalid baseURL:"
    static let warningMessage = "Using mock API key"

    static var apiKey: String {
        if let key = Bundle.main.object(
            forInfoDictionaryKey: Constants.сlientIDKey
        ) as? String {
            return key
        } else {
            AppLogger.api.warning("\(Constants.warningMessage)")
            return Constants.mockAPIKey
        }
    }
}

enum TuneBoxRouter {
    case getTracksByGenre(genre: String?, limit: Int, offset: Int)
    case getPopularTracks(limit: Int, offset: Int)
    case getTrackSize(id: Int)
    case searchTracks(query: String, limit: Int, offset: Int)
}

// MARK: - TargetType Protocol

extension TuneBoxRouter: TargetType {

    private typealias API = Constants.API
    private typealias Params = Constants.Params

    private var params: [String: Any] {
        switch self {
            case let .getTracksByGenre(genre, limit, offset):
                var params: [String: Any] = [
                    Params.clientID: Constants.apiKey,
                    Params.limit: limit,
                    Params.offset: offset
                ]

                if let genre, genre.isNotEmpty {
                    params[Params.tags] = genre
                }

                return params

            case let .getPopularTracks(limit, offset):
                return [
                    Params.clientID: Constants.apiKey,
                    Params.order: Constants.Values.popularityTotal,
                    Params.limit: limit,
                    Params.offset: offset
                ]

            case let .searchTracks(query, limit, offset):
                return [
                    Params.clientID: Constants.apiKey,
                    Params.search: query,
                    Params.limit: limit,
                    Params.offset: offset
                ]

            case .getTrackSize:
                return [:]
        }
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
