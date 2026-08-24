//
//  CoverViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.08.2026.
//

import Foundation
import Observation
import Resolver

@MainActor
@Observable
class CoverViewModel: CoverManaging {

    // MARK: - Properties. Public

    private(set) var isLoading = false
    private(set) var error: String?

    var isConnected: Bool {
        self.networkMonitorService.isConnected
    }

    // MARK: - Methods. Public

    func fetchFrontCover(artist: String, album: String) async -> Data? {
        self.isLoading = true

        defer {
            self.isLoading = false
        }

        do {
            return try await self.coverService.fetchFrontCover(artist: artist, album: album)
        } catch {
            self.error = AppError.API.from(error).errorDescription

            return nil
        }
    }

    // MARK: - Properties. Private

    @ObservationIgnored
    @Injected
    private var coverService: CoverServicing
    private let networkMonitorService = NetworkMonitorService.shared
}
