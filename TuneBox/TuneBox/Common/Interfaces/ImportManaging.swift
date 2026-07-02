//
//  ImportManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.06.2026.
//

import Foundation

protocol ImportManaging {
    var playlists: [PlaylistEntity] { get }
    var sections: [TracksSection] { get }
    var selectedTrackIDs: Set<String> { get }
    var showsEmptyState: Bool { get }

    func load() async
    func fetchPlaylists()
//    func createPlaylistDownloadedIfNeeded()
    func addImportItems(from urls: [URL]) async
    func toggleSelection(for id: String)
    func deleteSelectedTracks() async
    func removeImportedItem(by id: String) async
}
