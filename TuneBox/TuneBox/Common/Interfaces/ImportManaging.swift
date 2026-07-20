//
//  TestManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.07.2026.
//

import Foundation

protocol ImportManaging: LoadStateManaging {
    var editSectionModeEnabled: Bool { get set }
    var draggingLibraryItem: LibraryItem? { get set }
    var hasLibrary: Bool { get }
    var library: MusicLibrary? { get }
    var sections: [ImportSectionModel] { get }
    var sources: [ImportSource] { get }

    func fetchImportedData() async
    func fetchDownloadedData() async
    func startObservingTracksChanges()
    func stopObservingTracksChanges()
    func source(for id: ImportSource.ID) -> ImportSource?
    func playlist(for url: URL) -> PlaylistEntity?
    func fetchfolderItems(sourceID: ImportSource.ID, path: String?) async -> [SourceFolderItem]?
    func importFolder(_ url: URL) async
    func tracksSize(_ tracks: [TrackEntity]) -> Int
    func tracksDuration(_ tracks: [TrackEntity]) -> Int
    func toggleLibraryItem(_ item: LibraryItem)
    func isLibraryItemSelected(_ item: LibraryItem) -> Bool
    func moveLibraryItem(to target: LibraryItem)
    func beginEditSections()
    func finishEditSections()
    func dismissError()
}
