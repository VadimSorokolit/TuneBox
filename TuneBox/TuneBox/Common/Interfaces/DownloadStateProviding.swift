//
//  TransferStateProviding.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation

protocol DownloadStateProviding: AnyObject {
    var offsetPopular: Int { get }
    var sections: [TracksSection] { get }
    var selectedGenre: Genre { get set }
    var inProgressTrackIDs: Set<String> { get }
    var inProgressTracksCount: Int { get }
    var isRefreshing: Bool { get }
    var isGenreFirstLoading: Bool { get }
    var isPaginationPopularLoading: Bool { get }
    var isPaginationGenreLoading: Bool { get }
    var isPaginationSearchLoading: Bool { get }
    var shouldShowCentralSpinner: Bool { get }
    var reachedPopularTracksEnd: Bool { get }
    var reachedGenreTracksEnd: Bool { get }
    var reachedSearchTracksEnd: Bool { get }
    var completedSearchQuery: String { get }
    var error: String? { get }
}
