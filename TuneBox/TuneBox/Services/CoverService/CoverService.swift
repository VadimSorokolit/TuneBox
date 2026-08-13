//
//  CoverService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.08.2026.
//

import Foundation
import Moya

final class CoverService: CoverServicing {

    // MARK: - Methods. Public

    func fetchFrontCover(artist: String, album: String) async throws -> Data {
        return Data()
    }

    // MARK: - Initializer

    init(provider: MoyaProvider<CoverRouter>) {
        self.requestHandler = { target in
            try await provider.request(target)
        }
    }

    init(requestHandler: @escaping (CoverRouter) async throws -> Response) {
        self.requestHandler = requestHandler
    }

    // MARK: - Properties. Private

    private let requestHandler: (CoverRouter) async throws -> Response
}
