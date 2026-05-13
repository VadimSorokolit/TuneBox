//
//  TransferViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Foundation
import Observation

enum ReservedSpace: Int {
    case oneGB = 1
    case twoGB = 2
    case fiveGB = 5
}

protocol TransferStateProviding: AnyObject {
    var tracks: [Track] { get set }
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }

}

protocol TransferStorageStateProviding: AnyObject {
    var availableSpace: Double? { get }
    var reservedSpace: ReservedSpace { get set }
    func applyReservedSpace(_ plan: ReservedSpace)
}

typealias TransferManaging = TransferStateProviding & TransferStorageStateProviding

@MainActor
@Observable
final class TransferViewModel: TransferManaging {

    // MARK: Properties

    var tracks: [Track] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var availableSpace: Double? {
        self.storageService.getFreeStorage()
    }
    var reservedSpace: ReservedSpace = ReservedSpace.oneGB

    let networkService: NetworkServicing
    let storageService: StorageServicing

    // MARK: - Initializer

    init(networkService: NetworkServicing, storageService: StorageServicing) {
        self.networkService = networkService
        self.storageService = storageService
    }

    // MARK: - Methods

    func applyReservedSpace(_ plan: ReservedSpace) {
        do {
            try self.storageService.checkEnoughFreeStorage(requiredGB: Double(plan.rawValue))
            self.reservedSpace = plan
            print(reservedSpace.rawValue)
        } catch let error as StorageError {
            self.errorMessage = error.errorDescription
            print(self.errorMessage)
        } catch {
            self.errorMessage = error.localizedDescription
            print(self.errorMessage)
        }
    }
}
