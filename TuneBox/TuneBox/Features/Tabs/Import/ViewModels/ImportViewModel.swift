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

    // MARK: - Properties. Public

    private(set) var sections: [TracksSection] = []
    private(set) var selectedTrackIDs: Set<String> = []
    private(set) var error: String?

    var showsEmptyState: Bool {
        self.sections
            .allSatisfy { $0.tracks.isEmpty }
    }

    // MARK: - Methods. Public

    func load() async {
        await self.loadImported()
    }

    func loadImported() async {
        do {
            let tracks = try self.persistenceService.getImportTracks()
            self.set(tracks, for: .imported)
        } catch {
            self.handleError(error)
        }
    }

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

    func toggleSelection(for id: String) {
        if self.selectedTrackIDs.contains(id) {
            self.selectedTrackIDs.remove(id)
        } else {
            self.selectedTrackIDs.insert(id)
        }
    }

    func deleteSelectedTracks() async {
        for id in self.selectedTrackIDs {
            await self.removeImportedItem(by: id)
        }
        self.selectedTrackIDs.removeAll()
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

            if let index = self.sections.firstIndex(where: { $0.type == .imported }) {
                self.sections[index].tracks.removeAll { $0.id == track.id }
            }
        } catch {
            self.handleError(error)
        }
    }

    // MARK: - Initializer

    init() {
        self.ensureSectionsOrder()
    }

    // MARK: - Properties. Private

    @Injected
    @ObservationIgnored
    private var persistenceService: PersistenceServicing

    // MARK: - Methods. Private

    private func ensureSectionsOrder() {
        self.sections = [
            .init(type: .imported, tracks: [])
        ]
    }

    private func set(_ tracks: [TrackEntity], for type: TracksSection.SectionType) {
        if let index = sections.firstIndex(where: { $0.type == type }) {
            self.sections[index].tracks = tracks
        }
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.error = message
        AppLogger.imported.warning("\(message)")
    }
}
