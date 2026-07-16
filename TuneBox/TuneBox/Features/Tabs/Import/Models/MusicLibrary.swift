//
//  MusicLibrary.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.07.2026.
//

struct MusicLibrary {
    let albums: [Album]
    let artists: [Artist]
    let tracks: [TrackEntity]
    let playlists: [PlaylistEntity]

    struct Album: Identifiable, Hashable {
        let id: String
        let name: String
        let artist: String
        let tracks: [TrackEntity]
        let cover: String?
    }

    struct Artist: Identifiable, Hashable {
        let id: String
        let name: String
        let tracks: [TrackEntity]
        let albums: [Album]
    }
}
