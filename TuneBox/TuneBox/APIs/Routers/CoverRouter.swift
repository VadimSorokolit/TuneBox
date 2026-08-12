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

private struct Constants {}

enum CoverRouter {
    case searchReleaseBy(artist: String, album: String)
    case getFrontCover(mbid: String)
}

// MARK: - TargetType Protocol

extension CoverRouter: TargetType {
    
    var baseURL: URL {
        URL(string: "https://example.com")!
    }
    
    var path: String {
        ""
    }
    
    var method: Moya.Method {
        .get
    }
    
    var task: Moya.Task {
        .requestPlain
    }
    
    var headers: [String: String]? {
        nil
    }
    
}
