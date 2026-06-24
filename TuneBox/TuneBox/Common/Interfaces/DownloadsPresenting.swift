//
//  DownloadsPresenting.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.06.2026.
//

@MainActor
protocol DownloadsPresenting: AnyObject, Sendable {
    var isSearchLoading: Bool { get }
    var isSearchMode: Bool { get }
    var sections: [TracksSection] { get }
    var sectionTitleSuffix: String { get }
    var selectedTracksType: TracksType { get }
    var completedSearchQuery: String { get }

    func fetchTracksSectionBy(_ type: TracksType) async
    func handleSearchQuery(_ query: String) async
    func setResentTrackskLimit(_ limit: RecentTracksLimit)
    func setType(_ type: TracksType)
    func startObservingTracksChanges()
    func handleDownloadAction(for track: TrackEntity) async
    func clearSearchState()
}
