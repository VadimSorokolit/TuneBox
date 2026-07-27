//
//  AppRoute.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.07.2026.
//

import Foundation

enum AppRoute: Hashable {
    case launch
    case onboarding
    case main
    case albums
    case album(_ album: MusicLibrary.Album)
    case artists
    case artist(_ artist: MusicLibrary.Artist)
    case tracks(String?, TracksContent)
    case playlists
    case sourceFolder(sourceID: ImportSource.ID, path: String?)
}

extension AppRoute {

    static func tracks(
        navigationTitle: String? = nil,
        _ content: TracksContent
    ) -> AppRoute {
        .tracks(navigationTitle, content)
    }

}
