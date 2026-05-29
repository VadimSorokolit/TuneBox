//
//  TransferStateProviding.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation

protocol DownloadStateProviding: AnyObject {
    var offsetPopular: Int { get }
    var popularTracks: [TrackEntity] { get }
    var inProgressTrackIDs: Set<String> { get }
    var isLoading: Bool { get }
    var error: String? { get }
}
