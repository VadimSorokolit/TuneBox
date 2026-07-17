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

enum SourceKind: Hashable, Codable {
    case local
    case sync
    case api

    private enum CodingKeys: String, CodingKey {
        case type
        case syncType
    }

    private enum Kind: String, Codable {
        case local, sync, api
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
            case .local:
                self = .local

            case .api:
                self = .api

            case .sync:
                self = .sync
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .local:
                try container.encode(Kind.local, forKey: .type)

            case .api:
                try container.encode(Kind.api, forKey: .type)

            case .sync:
                try container.encode(Kind.sync, forKey: .type)
        }
    }

    var systemImage: String {
        switch self {
            case .local:
                return "folder"

            case .sync:
                return "network"

            case .api:
                return "globe"
        }
    }
}

struct ImportSource: Identifiable, Hashable, Codable {
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
    private(set) var sources: [ImportSource] = []
    private(set) var error: String?
    private(set) var isLoading: Bool = false
    var selectedLibraryItems: Set<LibraryItem> = []
    var libraryItemsOrder: [LibraryItem] = [.albums, .artists, .tracks, .playlists]
    var editSectionModeEnabled: Bool = false
    var draggingLibraryItem: LibraryItem?

    var hasLibrary: Bool {
        self.library != nil
    }

    // MARK: - Methods. Public

    func fetchImportedData() async {
        self.isLoading = true

        defer {
            self.isLoading = false
        }

        do {
            async let tracks = try self.persistenceService.getImportTracks()
                .sorted {
                    $0.songName.localizedCaseInsensitiveCompare($1.songName) == .orderedAscending
                }

            async let playlists = try self.persistenceService.fetchPlaylists()
                .sorted {
                    $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }

            let (downloadedTracks, downloadedPlaylists) = try await (tracks, playlists)

            if downloadedTracks.isNotEmpty {
                self.library = self.parseLibrary(from: downloadedTracks, playlists: downloadedPlaylists)
            }
        } catch {
            self.handleError(error)
        }
    }

    func folderItems(
        sourceID: ImportSource.ID,
        path: String?
    ) -> [SourceFolderItem] {
        guard
            let source = self.source(for: sourceID),
            let bookmarkData = source.bookmarkData
        else {
            return []
        }

        var isStale = false

        guard let rootURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return []
        }

        guard rootURL.startAccessingSecurityScopedResource() else {
            return []
        }

        defer {
            rootURL.stopAccessingSecurityScopedResource()
        }

        let currentURL: URL

        if let path, path.isNotEmpty {
            currentURL = rootURL.appendingPathComponent(path)
        } else {
            currentURL = rootURL
        }

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: currentURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])

            if values?.isDirectory == true {
                return SourceFolderItem(url: url, kind: .folder)
            }

            let extensionName = url.pathExtension.lowercased()

            if let ext = AudioFileExtension(rawValue: extensionName),
               self.supportedTrackExtensions.contains(ext) {
                return SourceFolderItem(url: url, kind: .track)
            }

            if let ext = PlaylistExtension(rawValue: extensionName),
               self.supportedPlaylistExtensions.contains(ext) {
                return SourceFolderItem(url: url, kind: .playlist)
            }

            return nil
        }
        .sorted {
            $0.url.lastPathComponent
                .localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
        }
    }

    func playlist(for url: URL) -> PlaylistEntity? {
        let title = url.deletingPathExtension().lastPathComponent

        return self.library?.playlists.first {
            $0.title == title
        }
    }

    func importFolder(_ url: URL) async {
        guard url.startAccessingSecurityScopedResource() else { return }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let kind: SourceKind = self.isNetworkFolder(url)
                ? .sync
                : .local

            let source = ImportSource(
                id: UUID(),
                kind: kind,
                title: url.lastPathComponent,
                bookmarkData: bookmarkData
            )
            self.addOrUpdateSource(source)

            let fileURLs = try self.collectFiles(from: url)

            let trackFiles = fileURLs.filter { url in
                guard let ext = AudioFileExtension(rawValue: url.pathExtension.lowercased()) else { return false }

                return self.supportedTrackExtensions.contains(ext)
            }

            let playlistFiles = fileURLs.filter { url in
                guard let ext = PlaylistExtension(rawValue: url.pathExtension.lowercased()) else { return false }

                return self.supportedPlaylistExtensions.contains(ext)
            }

            for file in trackFiles {
                await self.importTrack(from: file)
            }

            for playlistFile in playlistFiles {
                await self.importPlaylist(from: playlistFile)
            }

            await self.fetchImportedData()

        } catch {
            self.handleError(error)
        }
    }

    func source(for id: ImportSource.ID) -> ImportSource? {
        self.sources.first { $0.id == id }
    }

    func tracksSize(_ tracks: [TrackEntity]) -> Int {
        tracks.reduce(0) { $0 + ($1.size ?? 0) }
    }

    func tracksDuration(_ tracks: [TrackEntity]) -> Int {
        tracks.reduce(0) { $0 + ($1.duration ?? 0) }
    }

    func toggleLibraryItem(_ item: LibraryItem) {
        if self.selectedLibraryItems.contains(item) {
            self.selectedLibraryItems.remove(item)
        } else {
            self.selectedLibraryItems.insert(item)
        }
    }

    func isLibraryItemSelected(_ item: LibraryItem) -> Bool {
        self.selectedLibraryItems.contains(item)
    }

    func moveLibraryItem(to target: LibraryItem) {
        guard
            let from = self.draggingLibraryItem,
            from != target,
            let fromIndex = self.libraryItemsOrder.firstIndex(of: from),
            let toIndex = self.libraryItemsOrder.firstIndex(of: target)
        else {
            return
        }

        self.libraryItemsOrder.move(
            fromOffsets: IndexSet(integer: fromIndex),
            toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
        )
        self.ensureSections()
    }

    func beginEditSections() {
        self.editSectionModeEnabled = true
        self.ensureSections()
    }

    func finishEditSections() {
        self.editSectionModeEnabled = false
        self.draggingLibraryItem = nil
        self.saveSelectedLibraryItems()
        self.saveLibraryItemsOrder()
        self.ensureSections()
    }

    // MARK: - Initializer

    init() {
        self.loadLibraryItemsOrder()
        self.loadSelectedLibraryItems()
        self.loadSources()
        self.ensureSections()
    }

    // MARK: - Properties. Private

    @Injected
    @ObservationIgnored
    private var persistenceService: PersistenceServicing
    private let supportedPlaylistExtensions: Set<PlaylistExtension> = [.m3u, .m3u8]
    private let supportedTrackExtensions: Set<AudioFileExtension> = [.mp3, .wav, .wv, .flac]
    private enum Keys {
        static let selectedLibraryItems = "importSelectedLibraryItems"
        static let libraryItemsOrder = "importLibraryItemsOrder"
        static let importSources = "importSources"
    }

    // MARK: - Methods. Private

    private func ensureSections() {
        sections = [
            .init(
                kind: .library,
                items: librarySectionItems()
            ),
            .init(
                kind: .sources,
                items: sources.map { .source($0.id) }
            )
        ]
    }

    private func isNetworkFolder(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(
            forKeys:
                [
                    .volumeIsLocalKey,
                    .isUbiquitousItemKey
                ]
        ) else {
            return false
        }

        if values.isUbiquitousItem == true {
            return true
        }

        if values.volumeIsLocal == false {
            return true
        }

        return false
    }

    private func importTrack(from url: URL, into playlist: PlaylistEntity? = nil) async {
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
            let values = try localURL.resourceValues(forKeys: [.fileSizeKey])

            let fileSize = values.fileSize

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
                size: fileSize,
                localFilePath: localURL.path,
                sourceRawValue: TrackSource.imported.rawValue,
                downloadStateRawValue: DownloadState.completed.rawValue,
                fileStateRawValue: FileStorageState.exists.rawValue
            )

            try self.persistenceService.insert(tracks: [track])

            if let playlist {
                try self.persistenceService.addTrack(track, to: playlist)
            }
        } catch {
            self.handleError(error)
        }
    }

    private func importPlaylist(from url: URL) async {
        let title = url.deletingPathExtension().lastPathComponent
        let trackURLs = self.loadPlaylist(from: url)

        guard trackURLs.isNotEmpty else { return }

        do {
            let playlist = try self.persistenceService.createPlaylist(title: title)

            for trackURL in trackURLs {
                await self.importTrack(from: trackURL, into: playlist)
            }
        } catch {
            self.handleError(error)
        }
    }

    private func loadPlaylist(from url: URL) -> [URL] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        return content
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { url.deletingLastPathComponent().appendingPathComponent($0) }
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

    private func parseLibrary(from tracks: [TrackEntity], playlists: [PlaylistEntity]) -> MusicLibrary {
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
            .map { (name: String, artistTracks: [TrackEntity]) -> MusicLibrary.Artist in
                let albumNames = Set(
                    artistTracks
                        .map(\.albumName)
                        .filter { (albumName: String) in albumName.isNotEmpty }
                )

                let artistAlbums = albums.filter { (album: MusicLibrary.Album) in
                    albumNames.contains(album.name)
                }

                return MusicLibrary.Artist(
                    id: name,
                    name: name,
                    tracks: artistTracks,
                    albums: artistAlbums
                )
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        return MusicLibrary(
            albums: albums,
            artists: artists,
            tracks: tracks,
            playlists: playlists
        )
    }

    private func loadSelectedLibraryItems() {
        if let saved = UserDefaults.standard.stringArray(forKey: Keys.selectedLibraryItems) {
            self.selectedLibraryItems = Set(saved.compactMap(LibraryItem.init(rawValue:)))
        }

        if self.selectedLibraryItems.isEmpty {
            self.selectedLibraryItems = [.albums, .artists, .tracks, .playlists]
        }
    }

    private func loadLibraryItemsOrder() {
        if let saved = UserDefaults.standard.stringArray(forKey: Keys.libraryItemsOrder) {
            let parsed = saved.compactMap(LibraryItem.init(rawValue:))
            if parsed.isNotEmpty {
                self.libraryItemsOrder = parsed
                return
            }
        }

        self.libraryItemsOrder = [.albums, .artists, .tracks, .playlists]
    }

    private func saveSelectedLibraryItems() {
        UserDefaults.standard.set(
            self.selectedLibraryItems.map(\.rawValue),
            forKey: Keys.selectedLibraryItems
        )
    }

    private func saveLibraryItemsOrder() {
        UserDefaults.standard.set(
            libraryItemsOrder.map(\.rawValue),
            forKey: Keys.libraryItemsOrder
        )
    }

    private func addOrUpdateSource(_ source: ImportSource) {
        if let index = sources.firstIndex(where: { $0.title == source.title }) {
            sources[index] = source
        } else {
            sources.append(source)
        }
        saveSources()
        ensureSections()
    }
    private func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: Keys.importSources)
        }
    }
    private func loadSources() {
        guard
            let data = UserDefaults.standard.data(forKey: Keys.importSources),
            let saved = try? JSONDecoder().decode([ImportSource].self, from: data)
        else {
            sources = []
            return
        }
        sources = saved
    }

    private func librarySectionItems() -> [ImportItem] {
        let all = libraryItemsOrder

        let visible = self.editSectionModeEnabled
        ? all
        : all.filter { self.selectedLibraryItems.contains($0) }

        return visible.map { .library($0) }
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.error = message
        AppLogger.imported.warning("\(message)")
    }
}
