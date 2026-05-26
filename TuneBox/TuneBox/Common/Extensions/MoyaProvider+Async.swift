//
//  MoyaProvider+Async.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.05.2026.
//

import Foundation
import Moya

extension MoyaProvider {

    func request(_ target: Target) async throws -> Response {
        try await withCheckedThrowingContinuation { continuation in
            self.request(target) { result in
                continuation.resume(with: result)
            }
        }
    }

    func request<T: Decodable>(
        _ target: Target,
        as type: T.Type = T.self,
        decoder: JSONDecoder = .init()
    ) async throws -> T {
        let response = try await request(target)
        do {
            return try decoder.decode(T.self, from: response.data)
        } catch {
            let message = error.localizedDescription
            AppLogger.network.warning("JSON decode failed: \(message, privacy: .public)")
            throw MoyaError.objectMapping(error, response)
        }
    }

}
