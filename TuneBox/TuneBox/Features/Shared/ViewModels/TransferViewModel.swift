//
//  TransferViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Foundation
import Observation

protocol TransferManaging: AnyObject {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
}

@MainActor
@Observable
final class TransferViewModel {}
