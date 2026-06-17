//
//  DownloadsPresenting.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.06.2026.
//

protocol DownloadsPresenting {
    var sections: [TracksSection] { get }

    func fetchTracksSection() async
    func setTracksLimit(_ limit: RecentTracksLimit)
    func set(_ type: TracksType)
    func startObservingTracksChanges()
    func handleDownloadAction(for track: TrackEntity) async
}
