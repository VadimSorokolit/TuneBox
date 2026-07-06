//
//  ImportManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.06.2026.
//

import Foundation

protocol ImportManaging: AnyObject {
    var playlists: [PlaylistEntity] { get }
    var sections: [TracksSection] { get }
    var selectedTrackIDs: Set<String> { get }
    var showsEmptyState: Bool { get }
    var playlistAction: PlaylistAction? { get set }

    func load() async
    func fetchPlaylists()
    func createPlaylist(title: String)
    func renamePlaylist(_ playlist: PlaylistEntity, newTitle: String)
    func importFiles(_ urls: [URL], playlistTitle: String) async
    func deletePlaylist(_ playlist: PlaylistEntity)
    func setCoverImage(_ imageData: Data?, playlist: PlaylistEntity)
    func startObservingTracksChanges()
    func stopObservingTracksChanges()
    func createPlaylist(with urls: [URL]) async
    func addFiles(_ urls: [URL], to playlist: PlaylistEntity) async
    func toggleSelection(for id: String)
    func deleteSelectedTracks() async
    func removeTrack(track: TrackEntity, from playlist: PlaylistEntity) async
}
