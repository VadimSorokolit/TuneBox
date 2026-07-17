//
//  TestManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.07.2026.
//

import Foundation

protocol TestManaging: LoadStateManaging {
    var editSectionModeEnabled: Bool { get set }
    var draggingLibraryItem: LibraryItem? { get set }
    var hasLibrary: Bool { get }
    var library: MusicLibrary? { get }
    var sections: [ImportSectionModel] { get }

    func fetchImportedData() async
    func importFolder(_ url: URL) async
    func tracksSize(_ tracks: [TrackEntity]) -> Int
    func tracksDuration(_ tracks: [TrackEntity]) -> Int
    func toggleLibraryItem(_ item: LibraryItem)
    func isLibraryItemSelected(_ item: LibraryItem) -> Bool
    func moveLibraryItem(to target: LibraryItem)
    func beginEditSections()
    func finishEditSections()
}
