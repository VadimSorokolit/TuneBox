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
    case album(album: MusicLibrary.Album)
    case artist
    case tracks
    case playlists
}
