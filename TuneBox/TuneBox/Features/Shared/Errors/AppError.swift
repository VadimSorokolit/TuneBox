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
                    return L10n.Error.noInternet
                case .network(let error):
                    return L10n.Error.network(error.localizedDescription)
                case .decoding(let error):
                    return L10n.Error.decoding(error.localizedDescription)
                case .requestEncoding(let error):
                    return L10n.Error.encoding(error.localizedDescription)
                case .serverStatusCode(let code):
                    return L10n.Error.serverCode(code)
                case .invalidURL:
                    return L10n.Error.invalidURL
                case .notFound:
                    return L10n.Error.notFound
                case .missingContentLength:
                    return L10n.Error.missingContentLength
                case .invalidContentLength:
                    return L10n.Error.invalidContentLength
                case .unknown:
                    return L10n.Error.unknown
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
                                return .server(L10n.Error.serverUnavailable)

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
                    return L10n.Error.fileUnavailable
                case .notEnoughSpace(let requiredGB, let availableGB):
                    return L10n.Error.notEnoughSpace(required: requiredGB, available: availableGB)
            }
        }
    }

    enum Storage: LocalizedError {
        case reservedPlaylistTitle
        case playlistTitleAlreadyExists

        var errorDescription: String? {
            switch self {
                case .reservedPlaylistTitle:
                    return L10n.Error.reservedPlaylist
                case .playlistTitleAlreadyExists:
                    return L10n.Error.playlistExists
            }
        }
    }

    enum Playlist: LocalizedError {
        case emptyTitle
        case sameTitle

        var errorDescription: String? {
            switch self {
                case .emptyTitle:
                    return L10n.Error.playlistEmptyTitle

                case .sameTitle:
                    return L10n.Error.playlistSameTitle
            }
        }
    }

    enum File: Error {
        case missingDirectory
    }

    enum Source: LocalizedError {
        case networkUnavailable
        case accessDenied
        case bookmarkInvalid
        case readFailed(Error)

        var errorDescription: String? {
            switch self {
                case .networkUnavailable:
                    return L10n.Error.sourceNetworkUnavailable

                case .accessDenied:
                    return L10n.Error.sourceAccessDenied

                case .bookmarkInvalid:
                    return L10n.Error.sourceBookmarkInvalid

                case .readFailed(let error):
                    return error.localizedDescription
            }
        }
    }

}
