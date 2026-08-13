//
//  CoverServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.08.2026.
//

import Foundation

protocol CoverServicing {
    func fetchFrontCover(artist: String, album: String) async throws -> Data
}
