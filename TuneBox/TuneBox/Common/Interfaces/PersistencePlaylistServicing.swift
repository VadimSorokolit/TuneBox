//
//  PlaylistServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 01.07.2026.
//

import Foundation

protocol PersistencePlaylistServicing: AnyObject {
    func fetchPlaylists() throws -> [PlaylistEntity]
    func createSystemPlaylist() throws -> PlaylistEntity
    func createPlaylist(title: String) throws -> PlaylistEntity
    func renamePlaylist(_ playlist: PlaylistEntity, name: String) throws
    func deletePlaylist(_ playlist: PlaylistEntity) throws
    func addTrack(_ track: TrackEntity, to playlist: PlaylistEntity) throws
    func addTracks(_ tracks: [TrackEntity], to playlist: PlaylistEntity) throws
    func removeTrack(_ track: TrackEntity, from playlist: PlaylistEntity) throws
    func removeTracks(from playlist: PlaylistEntity) throws
    func setCoverImage(_ imageData: Data?, playlist: PlaylistEntity) throws
    func removeCoverImage(for playlist: PlaylistEntity) throws
}
