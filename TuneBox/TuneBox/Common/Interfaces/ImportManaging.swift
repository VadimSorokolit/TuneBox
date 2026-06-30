//
//  ImportManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.06.2026.
//

import Foundation

protocol ImportManaging {
    var importedTracks: [TrackEntity] { get }
    var showsEmptyState: Bool { get }

    func load() async
    func addImportItems(from urls: [URL]) async
    func removeImportedItem(by id: String) async
}
