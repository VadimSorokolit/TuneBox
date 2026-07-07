//
//  ImportViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.06.2026.
//

import Foundation
import Observation
import Resolver

enum PlaylistAction {
    case create
    case rename(PlaylistEntity)
    case addTracks(PlaylistEntity)
    case play(PlaylistEntity)
    case changeCover(PlaylistEntity)
    case deletePlaylist(PlaylistEntity)
    case deleteTracks(PlaylistEntity)
}

@MainActor
@Observable
final class ImportViewModel: ImportManaging {

    // MARK: - Properties. Public

    private(set) var playlists: [PlaylistEntity] = []
    private(set) var sections: [TracksSection] = []
    var selectedTrackIDs: Set<String> = []
    var selectedTracks: Set<TrackEntity> = []
    var playlistAction: PlaylistAction?
    private(set) var error: String?

    var showsEmptyState: Bool {
        self.playlists.isEmpty
    }

    // MARK: - Methods. Public

    func fetchPlaylists() {
        do {
            self.playlists = try self.persistenceService.fetchPlaylists()
        } catch {
            self.handleError(error)
        }
    }

    func createPlaylist(title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            guard title.isNotEmpty else {
                throw AppError.Playlist.emptyTitle
            }

            _ = try self.persistenceService.createPlaylist(title: title)
            self.fetchPlaylists()
        } catch {
            self.handleError(error)
        }
    }

    func renamePlaylist(_ playlist: PlaylistEntity, newTitle: String) {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            guard title.isNotEmpty else {
                throw AppError.Playlist.emptyTitle
            }

            guard title != playlist.title else {
                throw AppError.Playlist.sameTitle
            }

            try self.persistenceService.renamePlaylist(playlist, newTitle: title)
            self.fetchPlaylists()
        } catch {
            self.handleError(error)
        }
    }

    func setCoverImage(_ imageData: Data?, playlist: PlaylistEntity) {
        do {
            try self.persistenceService.setCoverImage(imageData, playlist: playlist)
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

    func createPlaylist(with urls: [URL]) async {
        for url in urls {
            if url.hasDirectoryPath {
                let needsStopAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if needsStopAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let mp3Files = (try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey]
                ))?.filter { file in
                    let isDirectory = (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                    return !isDirectory && file.pathExtension.lowercased() == "mp3"
                } ?? []

                guard mp3Files.isNotEmpty else { continue }

                let title = url.lastPathComponent
                guard let playlist = try? persistenceService.createPlaylist(title: title) else { continue }

                for file in mp3Files {
                    await importFile(file, into: playlist)
                }

            } else if url.pathExtension.lowercased() == "mp3" {
                await importFile(url, into: nil)
            } else {
                continue
            }
        }
        self.fetchPlaylists()
    }

    func addFiles(_ urls: [URL], to playlist: PlaylistEntity) async {
        for url in urls {
            await self.importFile(url, into: playlist)
        }
        self.fetchPlaylists()
    }

    func importPlaylistFolder(_ folderURL: URL) async {
        let needsStopAccess = folderURL.startAccessingSecurityScopedResource()

        defer {
            if needsStopAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        guard let m3u = files.first(where: {
            $0.pathExtension.lowercased() == "m3u"
        }) else {
            return
        }

        let trackURLs = self.loadPlaylist(from: m3u)

        do {
            let playlist = try self.persistenceService.createPlaylist(
                title: m3u.deletingPathExtension().lastPathComponent
            )

            for trackURL in trackURLs {
                await importFile(trackURL, into: playlist)
            }
            self.fetchPlaylists()
        } catch {
            self.handleError(error)
        }
    }

    func toogleSelection(for track: TrackEntity) {
        if self.selectedTracks.contains(track) {
            self.selectedTracks.remove(track)
        } else {
            self.selectedTracks.insert(track)
        }
    }

    func deleteSelectedTracks(from playlist: PlaylistEntity) async {
        for track in self.selectedTracks {
            await self.removeTrack(track: track, from: playlist)
        }
        self.selectedTracks.removeAll()
    }

    func deletePlaylist(_ playlist: PlaylistEntity) {
        do {
            try self.persistenceService.deletePlaylist(playlist)
            self.fetchPlaylists()
        } catch {
            self.handleError(error)
        }
    }

    func removeTrack(track: TrackEntity, from playlist: PlaylistEntity) async {
        switch playlist.type {
            case .system:
                self.removeDownloadedTrack(track: track)
                self.removeImportedTrack(track: track, from: playlist)

            case .custom:
                self.removeImportedTrack(track: track, from: playlist)
        }
    }

    private func removeDownloadedTrack(track: TrackEntity) {
        self.transferViewModel.deleteDownloadedTrack(track: track)
    }

    private func removeImportedTrack(track: TrackEntity, from playlist: PlaylistEntity) {
        do {
            try self.persistenceService.removeTrack(track, from: playlist)
            self.playlists = try self.persistenceService.fetchPlaylists()
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

            print("Downloaded tracks:", downloadedTracks.count)

            if downloadedTracks.isNotEmpty {
                print("Calling createSystemPlaylist")

                let systemPlaylist = try self.persistenceService.createSystemPlaylist()

                print("Created/found:", systemPlaylist.title)

                systemPlaylist.tracks = downloadedTracks
            } else {
                print("No downloaded tracks")
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
            let name = metadata?.title ?? url.deletingPathExtension().lastPathComponent
            let artist = metadata?.artist ?? ""

            if let playlist,
               self.trackAlreadyExists(name: name, artist: artist, in: playlist) {
                try? FileManager.default.removeItem(at: localURL)

                return
            }

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

            try self.persistenceService.insert(tracks: [entity])

            if let playlist {
                try self.persistenceService.addTrack(entity, to: playlist)
            }

        } catch {
            self.handleError(error)
        }
    }

    private func loadPlaylist(from url: URL) -> [URL] {
        guard let content = try? String(
            contentsOf: url,
            encoding: .utf8
        ) else {
            return []
        }

        return content
            .components(separatedBy: .newlines)
            .filter {
                !$0.isEmpty &&
                !$0.hasPrefix("#")
            }
            .map {
                url
                    .deletingLastPathComponent()
                    .appendingPathComponent($0)
            }
    }

    func importFiles(_ urls: [URL], playlistTitle: String) async {
        let title = playlistTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            guard title.isNotEmpty else {
                throw AppError.Playlist.emptyTitle
            }
            let playlist = try self.persistenceService.createPlaylist(title: title)

            for url in urls {
                await self.importFile(url, into: playlist)
            }

            self.fetchPlaylists()
        } catch {
            self.handleError(error)
        }
    }

    private func trackAlreadyExists(
        name: String,
        artist: String,
        in playlist: PlaylistEntity
    ) -> Bool {
        playlist.tracks.contains {
            $0.songName == name &&
            $0.artistName == artist
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
