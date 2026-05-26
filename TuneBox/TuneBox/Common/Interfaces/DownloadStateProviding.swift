//
//  TransferStateProviding.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation

protocol DownloadStateProviding: AnyObject {
    var offset: Int { get set }
    var tracks: [TrackEntity] { get set }
    var inProgressTrackIDs: Set<String> { get set }
    var isLoading: Bool { get set }
    var error: String? { get set }
}
