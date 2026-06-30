//
//  ImportViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.06.2026.
//

import Foundation
import Observation
import Resolver

@MainActor
@Observable
final class ImportViewModel: ImportManaging {

    // MARK: - State

    private(set) var importedTracks: [TrackEntity] = []
    private(set) var error: String?

    var showsEmptyState: Bool {
        self.importedTracks.isEmpty
    }

    // MARK: - Load

    func load() async {
        await self.loadImported()
    }

    func loadImported() async {
        do {
            self.importedTracks = try self.persistenceService.getImportTracks()
        } catch {
            self.handleError(error)
        }
    }

    // MARK: - Actions

    func addImportItems(from urls: [URL]) async {
        for url in urls {
            do {
                let localURL = try FileManagerService.storeImportedFile(
                    from: url,
                    id: UUID().uuidString
                )

                let entity = TrackEntity(
                    id: url.absoluteString,
                    image: nil,
                    songName: url.deletingPathExtension().lastPathComponent,
                    duration: nil,
                    artistName: "",
                    albumName: "",
                    releaseDate: nil,
                    download: nil,
                    waveformData: nil,
                    size: nil,
                    localFilePath: localURL.path,
                    sourceRawValue: TrackSource.imported.rawValue,
                    downloadStateRawValue: DownloadState.completed.rawValue,
                    fileStateRawValue: FileStorageState.exists.rawValue
                )

                try self.persistenceService.insert(tracks: [entity])
            } catch {
                self.handleError(error)
            }
        }

        await self.loadImported()
    }

    func removeImportedItem(by id: String) async {
        do {
            guard let track = try self.persistenceService.getTrack(id: id) else {
                return
            }

            if let url = track.localFileURL {
                try? FileManager.default.removeItem(at: url)
            }

            try self.persistenceService.delete(track: track)
            self.importedTracks.removeAll { $0.id == id }
        } catch {
            self.handleError(error)
        }
    }

    // MARK: - Private

    @Injected
    @ObservationIgnored
    private var persistenceService: PersistenceServicing

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.error = message
        AppLogger.imported.warning("\(message)")
    }
}
