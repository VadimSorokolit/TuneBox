//
//  AppError.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.05.2026.
//

import Foundation
import Moya

enum AppError: Error {

    enum API: LocalizedError {
        case noInternet
        case network(Error)
        case decoding(Error)
        case requestEncoding(Error)
        case server(String)
        case serverStatusCode(Int)
        case invalidURL
        case notFound
        case missingContentLength
        case invalidContentLength
        case unknown

        var errorDescription: String? {
            switch self {
                    /**
                     - Note:
                     API Docs: - https://developer.jamendo.com/v3.0/response-codes
                     */
                case .server(let message):
                    return message
                case .noInternet:
                    return "No internet connection"
                case .network(let error):
                    return "Network error: \(error.localizedDescription)"
                case .decoding(let error):
                    return "Decoding error: \(error.localizedDescription)"
                case .requestEncoding(let error):
                    return "Request encoding error: \(error.localizedDescription)"
                case .serverStatusCode(let code):
                    return "Server error (code: \(code))"
                case .invalidURL:
                    return "Invalid URL"
                case .notFound:
                    return "Requested resource not found"
                case .missingContentLength:
                    return "Missing Content-Length header"
                case .invalidContentLength:
                    return "Invalid Content-Length value"
                case .unknown:
                    return "Unknown error"
            }
        }

        static func from(_ error: Error) -> API {
            if let apiError = error as? API {
                return apiError
            }

            if let moyaError = error as? MoyaError {
                switch moyaError {
                    case .objectMapping(let underlying, _):
                        return .decoding(underlying)

                    case .encodableMapping(let error):
                        return .requestEncoding(error)

                    case .statusCode(let response):
                        switch response.statusCode {
                            case 404:
                                return .notFound

                            case 500 ... 599:
                                return .server("Server is unavailable")

                            default:
                                return .serverStatusCode(response.statusCode)
                        }

                    case .underlying(let underlying, _):
                        return from(underlying)

                    default:
                        return .network(moyaError)
                }
            }

            if let decodingError = error as? DecodingError {
                return .decoding(decodingError)
            }

            if let urlError = error as? URLError {
                return mapURLError(urlError)
            }

            return .network(error)
        }

        private static func mapURLError(_ error: URLError) -> API {
            switch error.code {
                case .notConnectedToInternet,
                        .cannotConnectToHost,
                        .networkConnectionLost,
                        .timedOut:
                    return .noInternet

                case .cannotFindHost,
                        .dnsLookupFailed,
                        .badURL,
                        .unsupportedURL:
                    return .invalidURL

                default:
                    return .network(error)
            }
        }
    }

    enum FileManager: LocalizedError {
        case unavailable
        case notEnoughSpace(requiredGB: Double, availableGB: Double)

        var errorDescription: String? {
            switch self {
                case .unavailable:
                    return "Unable to determine available storage."
                case .notEnoughSpace(let requiredGB, let availableGB):
                    return "Not enough free space. Required: \(requiredGB) GB, available: \(availableGB) GB."
            }
        }
    }

    enum Storage: LocalizedError {
        case reservedPlaylistTitle
        case playlistTitleAlreadyExists

        var errorDescription: String? {
            switch self {
                case .reservedPlaylistTitle:
                    return "Name \"Downloaded\" is reserved"
                case .playlistTitleAlreadyExists:
                    return "Playlist with this name already exists"
            }
        }
    }

    enum Playlist: LocalizedError {
        case emptyTitle
        case sameTitle

        var errorDescription: String? {
            switch self {
                case .emptyTitle:
                    return "Playlist title cannot be empty"

                case .sameTitle:
                    return "The playlist already has this title"
            }
        }
    }

    enum File: Error {
        case missingDirectory
    }

}
