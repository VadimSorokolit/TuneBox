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

private struct Constants {
    static let googleBaseURL = "google.com"
    static let paginationLimit: Int = 20
    
    static var apiKey: String {
        if let key = ProcessInfo.processInfo.environment["APIKey"] {
            return key
        } else {
            AppLogger.api.warning("Using mock API key")
            return "88888888"
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
    
    var baseURL: URL {
        let urlString: String
        
        switch self {
            case .getSongSize:
                urlString = "https://prod-1.storage.jamendo.com"
            default:
                urlString = "https://api.jamendo.com/v3.0"
        }
        
        guard let url = URL(string: urlString) ?? URL(string: Constants.googleBaseURL) else {
            fatalError("Invalid baseURL: \(urlString)")
        }
        
        return url
    }
    
    var path: String {
        switch self {
            case .getSongSize(let id):
                return "/download/track/\(id)/mp32/"
                
            case .getTracksByGenre, .getPopularTracks, .searchTracks:
                return "/tracks"
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
            case let .getTracksByGenre(genre, limit):
                return .requestParameters(
                    parameters: [
                        "client_id": Constants.apiKey,
                        "tags": genre,
                        "limit": limit
                    ],
                    encoding: URLEncoding.default
                )
                
            case let .getPopularTracks(limit):
                return .requestParameters(
                    parameters: [
                        "client_id": Constants.apiKey,
                        "order": "popularity_total",
                        "limit": limit
                    ],
                    encoding: URLEncoding.default
                )
                
            case let .searchTracks(query, limit, offset):
                return .requestParameters(
                    parameters: [
                        "client_id": Constants.apiKey,
                        "search": query,
                        "limit": limit,
                        "offset": offset
                    ],
                    encoding: URLEncoding.default
                )
                
            case .getSongSize:
                return .requestPlain
        }
    }
    
    var headers: [String: String]? {
        nil
    }
    
}
