//
//  TracksResponse.swift
//  TuneBox
//
//  Created by Nintendo on 07.05.2026.
//

struct TracksResponse: Decodable {
    let headers: ResponseHeaders
    let results: [Track]
}

struct ResponseHeaders: Decodable {
    let status: String
    let code: Int
    let errorMessage: String

    enum CodingKeys: String, CodingKey {
        case status
        case code
        case errorMessage = "error_message"
    }
}
