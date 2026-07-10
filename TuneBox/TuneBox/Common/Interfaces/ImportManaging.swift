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
    var selectedTrack: TrackEntity? { get set }
    var selectedTracks: Set<TrackEntity> { get set }
    var selectedPlaylists: Set<ImportedPlaylist> { get set }
    var selectedTrackIDs: Set<String> { get set }
    var showsEmptyState: Bool { get }
    var playlistAction: PlaylistAction? { get set }

    func load() async
    func fetchPlaylists()
    func createPlaylist(title: String)
    func createSelectedPlaylists() async
    func renamePlaylist(_ playlist: PlaylistEntity, newTitle: String)
    func importFiles(_ urls: [URL], playlistTitle: String) async
    func loadPlaylists(from folderURL: URL) -> [ImportedPlaylist]
    func deletePlaylist(_ playlist: PlaylistEntity)
    func setCoverImage(_ imageData: Data?, playlist: PlaylistEntity)
    func startObservingTracksChanges()
    func stopObservingTracksChanges()
    func createPlaylist(with urls: [URL]) async
    func addFiles(_ urls: [URL], to playlist: PlaylistEntity) async
    func toogleSelection(for track: TrackEntity)
    func toogleSelection(for playlist: ImportedPlaylist)
    func deleteSelectedTracks(from playlist: PlaylistEntity) async
    func removeTrack(track: TrackEntity, from playlist: PlaylistEntity) async
}
