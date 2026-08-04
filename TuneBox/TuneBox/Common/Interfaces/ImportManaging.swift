//
//  TestManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.07.2026.
//

import Foundation

protocol ImportManaging: LoadStateManaging {
    var isEditSectionModeEnabled: Bool { get }
    var draggingItem: ImportItem? { get set }
    var hasLibrary: Bool { get }
    var hasVisibleItems: Bool { get }
    var library: MusicLibrary? { get }
    var sections: [ImportSectionModel] { get }
    var sources: [ImportSource] { get }

    func refreshLibrary() async
    func sortedTracksAlphabetically(_ tracks: [TrackEntity]) -> [TrackEntity]
    func startObservingTracksChanges()
    func stopObservingTracksChanges()
    func source(for id: ImportSource.ID) -> ImportSource?
    func playlist(for url: URL) -> PlaylistEntity?
    func fetchfolderItems(sourceID: ImportSource.ID, path: String?) async -> [SourceFolderItem]?
    func importFolder(_ url: URL) async
    func track(for url: URL) -> TrackEntity?
    func tracks(for sourceID: ImportSource.ID) -> [TrackEntity]
    func tracksSize(_ tracks: [TrackEntity]) -> Int
    func sourceTracksSummary(for sourceID: ImportSource.ID) -> (count: Int, duration: Int, size: Int)
    func sourceStorageSize(for item: ImportItem) -> String?
    func tracksDuration(_ tracks: [TrackEntity]) -> Int
    func toggleItem(_ item: ImportItem)
    func isItemSelected(_ item: ImportItem) -> Bool
    func moveItem(to target: ImportItem)
    func sectionedTracks(from tracks: [TrackEntity]) -> [TrackAlphabetSection]
    func libraryTracks(onlyAPI: Bool) -> [TrackEntity]
    func beginEditSections()
    func finishEditSections()
    func removeSource(_ id: ImportSource.ID) async
    func dismissError()
}

extension ImportManaging {

    func libraryTracks(onlyAPI: Bool = false) -> [TrackEntity] {
        libraryTracks(onlyAPI: onlyAPI)
    }

}
