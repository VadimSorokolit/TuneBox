//
//  TestViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.07.2026.
//

import Foundation
import Observation
import Resolver

enum ImportSection: String, Hashable {
    case library
    case sources
}

enum LibraryItem: String, Hashable {
    case albums
    case artists
    case tracks
    case playlists

    var systemImage: String {
        switch self {
            case .albums:
                return "square.stack"

            case .artists:
                return "music.mic"

            case .tracks:
                return "music.note"

            case .playlists:
                return "music.note.list"
        }
    }
}

enum SourceKind: Hashable {
    case local
    case sync(SyncType)
    case api

    var addTitle: String {
        switch self {
            case .local:
                return "Add Folder"
            case .sync(.mac):
                return "Sync from Mac"
            case .api:
                return "Jamendo"
        }
    }

    var systemImage: String {
        switch self {
            case .local:
                return "folder"

            case .sync:
                return "desktopcomputer"

            case .api:
                return "globe"
        }
    }
}

enum SyncType: Hashable {
    case mac
}

struct ImportSource: Identifiable, Hashable {
    let id: UUID
    let kind: SourceKind
    let title: String
    /// Security-scoped bookmark for local folder
    let bookmarkData: Data?
}

// MARK: - Home items

enum ImportItem: Hashable {
    case library(LibraryItem)
    case source(ImportSource.ID)
    case addSource(SourceKind)
}

// MARK: - Section model

struct ImportSectionModel: Hashable, Identifiable {
    let kind: ImportSection
    var items: [ImportItem]

    var id: ImportSection { kind }
}

// MARK: - Navigation

enum ImportDestination: Hashable {
    case source(ImportSource.ID)
    case item(
        sourceID: ImportSource.ID?,
        item: LibraryItem
    )
    case folder(
        sourceID: ImportSource.ID,
        path: String
    )
    case album(String)
    case artist(String)
    case track(String)
    case playlist(String)
}

@MainActor
@Observable
final class TestViewModel: TestManaging {

    // MARK: - Properties. Public

    private(set) var sections: [ImportSectionModel] = []
    private(set) var library: MusicLibrary?
    private(set) var error: String?
    private(set) var isLoading: Bool = false
    var editSectionModeEnabled: Bool = false

    var hasLibrary: Bool {
        self.library != nil
    }

    // MARK: - Methods. Public

    func fetchImportedTracks() async {
        self.isLoading = true

        defer {
            self.isLoading = false
        }

        do {
            let tracks = try self.persistenceService.getImportTracks()
                .sorted {
                    $0.songName.localizedCaseInsensitiveCompare($1.songName) == .orderedAscending
                }

            if tracks.isNotEmpty {
                self.library = self.parseLibrary(from: tracks)
            }
        } catch {
            self.handleError(error)
        }
    }

    func importFolder(_ url: URL) async {
        guard url.startAccessingSecurityScopedResource() else { return }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        do {
            let fileURLs = try self.collectFiles(from: url)

            for fileURL in fileURLs {
                await self.importTrack(from: fileURL)
            }

            await self.fetchImportedTracks()

        } catch {
            self.handleError(error)
        }
    }

    // MARK: - Initializer

    init() {
        self.ensureSections()
    }

    // MARK: - Properties. Private

    @Injected
    @ObservationIgnored
    private var persistenceService: PersistenceServicing
    private let supportedPlaylistExtensions: Set<PlaylistExtension> = [.m3u, .m3u8]
    private let supportedTrackExtensions: Set<AudioFileExtension> = [.mp3, .wav, .wv, .flac]

    // MARK: - Methods. Private

    private func ensureSections() {
        guard self.sections.isEmpty else { return }

        self.sections = [
            .init(
                kind: .library,
                items: [
                    .library(.albums),
                    .library(.artists),
                    .library(.tracks),
                    .library(.playlists)
                ]
            ),
            .init(
                kind: .sources,
                items: [
                    .addSource(.local),
                    .addSource(.sync(.mac)),
                    .addSource(.api)
                ]
            )
        ]
    }

    private func importTrack(from url: URL) async {
        let ext = url.pathExtension.lowercased()

        guard
            let fileExtension = AudioFileExtension(rawValue: ext),
            self.supportedTrackExtensions.contains(fileExtension)
        else {
            return
        }

        do {
            let id = UUID().uuidString

            let localURL = try FileManagerService.storeImportedFile(
                from: url,
                id: id
            )

            let metadata = try? await AudioMetadataService.extractMetadata(from: localURL)

            var artworkPath: String?

            let artwork = metadata?.artwork ?? folderArtwork(near: url)

            if let artwork {
                let artworkURL = try AudioMetadataService.save(
                    artwork,
                    trackID: id
                )
                artworkPath = artworkURL.lastPathComponent
            }

            let duration = metadata?.duration.map {
                Int($0.rounded())
            }

            let fileBase = url.deletingPathExtension().lastPathComponent

            let track = TrackEntity(
                id: id,
                image: artworkPath,
                songName: metadata?.title ?? fileBase,
                duration: duration,
                artistName: metadata?.artist ?? "",
                albumName: metadata?.album ?? fileBase,
                releaseDate: nil,
                download: nil,
                waveformData: nil,
                size: nil,
                localFilePath: localURL.path,
                sourceRawValue: TrackSource.imported.rawValue,
                downloadStateRawValue: DownloadState.completed.rawValue,
                fileStateRawValue: FileStorageState.exists.rawValue
            )

            try self.persistenceService.insert(tracks: [track])

        } catch {
            self.handleError(error)
        }
    }

    private func folderArtwork(near fileURL: URL) -> Data? {
        let dir = fileURL.deletingLastPathComponent()
        let preferred = ["cover.jpg", "folder.jpg", "Cover.jpg", "Folder.jpg"]
        for name in preferred {
            let url = dir.appendingPathComponent(name)
            if let data = try? Data(contentsOf: url) {
                return data
            }
        }
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        return files
            .first { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" }
            .flatMap { try? Data(contentsOf: $0) }
    }

    private func collectFiles(from url: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }

        var files: [URL] = []

        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(
                forKeys: [.isDirectoryKey]
            )

            if values.isDirectory != true {
                files.append(fileURL)
            }
        }

        return files
    }

    private func parseLibrary(from tracks: [TrackEntity]) -> MusicLibrary {
        let albums = Dictionary(grouping: tracks.filter { $0.albumName.isNotEmpty }) {
            $0.albumName
        }
        .map { name, tracks in
            MusicLibrary.Album(
                id: name,
                name: name,
                artist: tracks.first?.artistName ?? "",
                tracks: tracks,
                cover: tracks.first?.imagePath
            )
        }
        .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        let artists = Dictionary(grouping: tracks.filter { $0.artistName.isNotEmpty }) {
            $0.artistName
        }
        .map { name, tracks in
            MusicLibrary.Artist(
                id: name,
                name: name,
                tracks: tracks,
                albums: Set(tracks.map(\.albumName).filter(\.isNotEmpty))
            )
        }
        .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        return MusicLibrary(
            albums: albums,
            artists: artists,
            tracks: tracks,
            playlists: []
        )
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.error = message
        AppLogger.imported.warning("\(message)")
    }
}
