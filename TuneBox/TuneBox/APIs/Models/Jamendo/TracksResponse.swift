//
//  TracksResponse.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.05.2026.
//

struct TracksResponse: Decodable {
    let headers: ResponseHeaders
    let results: [TrackDTO]
}

struct ResponseHeaders: Decodable {
    let status: String
    let code: Int
    let errorMessage: String?
    let resultsCount: Int
    let next: String?

    enum CodingKeys: String, CodingKey {
        case status
        case code
        case errorMessage = "error_message"
        case resultsCount = "results_count"
        case next = "next"
    }
}
