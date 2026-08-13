//
//  CoverRouter.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 12.08.2026.
//

import Foundation
import Moya

/**
 - Note:
 Docs:
 - https://musicbrainz.org/doc/MusicBrainz_API
 - https://musicbrainz.org/doc/Cover_Art_Archive/API
 */

private enum CoverSize: String {
    case small = "250"
    case medium = "500"
    case large = "1200"
    case original = ""
}

private struct Constants {
    struct API {
        static let baseURL = "https://musicbrainz.org"
        static let coverURL = "https://coverartarchive.org"
        static let releasePath = "/ws/2/release"
        static let coverReleasePath = "/release/%@"
    }

    struct Params {
        static let query = "query"
        static let format = "fmt"
    }

    struct Values {
        static let json = "json"
        static let front = "front-\(CoverSize.medium.rawValue)"
        static let userAgent = "TuneBox/1.0 (macintosh@ukr.net)"
    }
    
    struct SearchOperator {
        static let and = "AND"
    }
    
    struct SearchField {
        static let artist = "artist"
        static let release = "release"
    }
}

enum CoverRouter {
    case getReleaseBy(artist: String, album: String)
    case getFrontCover(mbid: String)
}

// MARK: - TargetType Protocol

extension CoverRouter: TargetType {

    private typealias API = Constants.API
    private typealias Params = Constants.Params
    private typealias Values = Constants.Values
    private typealias SearchOperator = Constants.SearchOperator
    private typealias SearchField = Constants.SearchField

    var baseURL: URL {
        let urlString: String

        switch self {
            case .getFrontCover:
                urlString = API.coverURL

            default:
                urlString = API.baseURL
        }

        guard let url = URL(string: urlString) ?? URL(string: GlobalConstants.API.fallbackBaseURL) else {
            fatalError("\(GlobalConstants.API.invalidURLMessage) \(urlString)")
        }

        return url
    }

    var path: String {
        switch self {
            case .getReleaseBy:
                return API.releasePath
            case .getFrontCover(let mbid):
                return "\(String(format: API.coverReleasePath, mbid))/\(Values.front)"
        }
    }

    var method: Moya.Method {
        .get
    }

    var task: Moya.Task {
        switch self {
            case .getReleaseBy(let artist, let album):
                let query = """
                \(SearchField.artist):"\(artist)" \(SearchOperator.and) \(SearchField.release):"\(album)"
                """
                
                return .requestParameters(
                    parameters: [
                        Params.query: query,
                        Params.format: Values.json
                    ],
                    
                    encoding: URLEncoding.queryString
                )
                
            case .getFrontCover:
                return .requestPlain
        }
    }

    var headers: [String: String]? {
        ["User-Agent": Values.userAgent]
    }

}
