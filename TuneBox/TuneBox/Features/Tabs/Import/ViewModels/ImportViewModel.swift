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

    private(set) var playlists: [PlaylistEntity] = []
    private(set) var sections: [TracksSection] = []
    private(set) var selectedTrackIDs: Set<String> = []
    private(set) var error: String?

    var showsEmptyState: Bool {
        self.playlists.isEmpty
    }

    // MARK: - Methods. Public

    func fetchPlaylists() {
        do {
            self.playlists = try self.persistenceService.fetchPlaylists()
            print(self.playlists.count)
        } catch {
            self.handleError(error)
        }

    }

    func createPlaylist(title: String) {
        do {
            _ = try self.persistenceService.createPlaylist(title: title)
            self.fetchPlaylists()
        } catch {
            self.handleError(error)
        }
    }

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

    func startObservingTracksChanges() {
        self.tracksObservationTask?.cancel()

        self.tracksObservationTask = Task { [weak self] in
            guard let self else { return }

            self.syncSystemPlaylist()

            self.transferViewModel.onTracksChanged = { [weak self] in
                guard let self else { return }

                Task {
                    self.syncSystemPlaylist()
                }
            }
        }
    }

    func stopObservingTracksChanges() {
        self.tracksObservationTask?.cancel()
        self.tracksObservationTask = nil
        self.transferViewModel.onTracksChanged = nil
    }

    func addImportItems(from urls: [URL]) async {
        for url in urls {
            if url.hasDirectoryPath {
                let title = url.lastPathComponent

                guard let playlist = try? self.persistenceService.createPlaylist(title: title) else {
                    continue
                }

                await self.importFolder(url, into: playlist)
            } else {
                await self.importFile(url, into: nil)
            }
        }
        self.fetchPlaylists()
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

            await self.loadImported()
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
    private var transferViewModel: TransferManaging
    @Injected
    @ObservationIgnored
    private var persistenceService: PersistenceServicing
    private var tracksObservationTask: Task<Void, Never>?

    // MARK: - Methods. Private

    private func ensureSectionsOrder() {
        self.sections = [
            .init(type: .imported, tracks: [])
        ]
    }

    private func syncSystemPlaylist() {
        do {
            let downloadedTracks = try self.persistenceService.getRecentDownloadedTracks(limit: nil)

            if downloadedTracks.isNotEmpty {
                let systemPlaylist = try self.persistenceService.createSystemPlaylist()
                systemPlaylist.tracks = downloadedTracks
            }

            self.playlists = try self.persistenceService.fetchPlaylists()

        } catch {
            self.handleError(error)
        }
    }

    private func importFolder(_ url: URL, into playlist: PlaylistEntity) async {
        guard url.startAccessingSecurityScopedResource() else { return }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey]
            )

            for file in files {
                let values = try file.resourceValues(forKeys: [.isDirectoryKey])

                if values.isDirectory == false {
                    await self.importFile(file, into: playlist)
                }
            }
        } catch {
            self.handleError(error)
        }

        url.stopAccessingSecurityScopedResource()
    }

    private func importFile(_ url: URL, into playlist: PlaylistEntity?) async {
        do {
            let id = UUID().uuidString

            let localURL = try FileManagerService.storeImportedFile(
                from: url,
                id: id
            )

            let metadata = try? await AudioMetadataService.extractMetadata(from: localURL)

            var artworkPath: String?

            if let artworkData = metadata?.artwork {
                let fileURL = try AudioMetadataService.save(artworkData, trackID: id)
                artworkPath = fileURL.path
            }

            let duration: Int? = {
                guard let seconds = metadata?.duration, seconds.isFinite, seconds > 0 else {
                    return nil
                }

                return Int(seconds.rounded())
            }()

            let entity = TrackEntity(
                id: id,
                image: artworkPath,
                songName: metadata?.title ?? url.deletingPathExtension().lastPathComponent,
                duration: duration,
                artistName: metadata?.artist ?? "",
                albumName: metadata?.album ?? "",
                releaseDate: nil,
                download: nil,
                waveformData: nil,
                size: nil,
                localFilePath: localURL.path,
                sourceRawValue: TrackSource.imported.rawValue,
                downloadStateRawValue: DownloadState.completed.rawValue,
                fileStateRawValue: FileStorageState.exists.rawValue
            )

            try persistenceService.insert(tracks: [entity])

        } catch {
            self.handleError(error)
        }
    }

    private func set(_ tracks: [TrackEntity], for type: TracksSection.SectionType) {
        if let index = sections.firstIndex(where: { $0.type == type }) {
            self.sections[index].tracks = tracks
        }
    }

    private func set(_ tracks: [TrackEntity], for playlist: PlaylistEntity) {
        if let index = self.playlists.firstIndex(where: { $0.id == playlist.id }) {
            self.playlists[index].tracks = tracks
        }
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.error = message
        AppLogger.imported.warning("\(message)")
    }
}
