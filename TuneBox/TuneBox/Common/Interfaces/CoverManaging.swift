//
//  CoverManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.08.2026.
//

import Foundation

protocol CoverManaging: LoadStateManaging, NetworkMonitoring {
    func fetchFrontCover(artist: String, album: String) async -> Data?
}
