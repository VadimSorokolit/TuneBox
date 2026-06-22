//
//  DownloadsPresenting.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.06.2026.
//

@MainActor
protocol DownloadsPresenting: AnyObject, Sendable {
    var isSearchLoading: Bool { get }
    var sections: [TracksSection] { get }
    var selectedTracksType: TracksType { get }
    var completedSearchQuery: String { get }

    func fetchTracksSection() async
    func loadSearchBy(query: String)
    func setTracksLimit(_ limit: RecentTracksLimit)
    func set(_ type: TracksType)
    func startObservingTracksChanges()
    func handleDownloadAction(for track: TrackEntity) async
    func clearSearchState()
}
