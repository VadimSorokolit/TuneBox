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

private struct DeduplicationKey: Hashable {
    let songName: String
    let artistName: String
}

enum ImportItem: Hashable {
    case library(LibraryItem)
    case source(ImportSource.ID)
}

struct ImportSectionModel: Hashable, Identifiable {
    let kind: ImportSection
    var items: [ImportItem]

    var id: ImportSection { kind }
}

@MainActor
@Observable
final class ImportViewModel: ImportManaging {

    // MARK: - Properties. Public

    private(set) var sections: [ImportSectionModel] = []
    private(set) var library: MusicLibrary?
    private(set) var sources: [ImportSource] = []
    private(set) var error: String?
    private(set) var isLoading: Bool = false
    private(set) var selectedLibraryItems: Set<LibraryItem> = []
    private(set) var selectedSourceIDs: Set<ImportSource.ID> = []
    private(set) var libraryItemsOrder: [LibraryItem] = [.albums, .artists, .tracks, .playlists]
    private(set) var isEditSectionModeEnabled: Bool = false
    var draggingItem: ImportItem?

    var hasLibrary: Bool {
        self.library != nil
    }

    var hasVisibleItems: Bool {
        self.sections.contains { $0.items.isNotEmpty }
    }

    // MARK: - Methods. Public

    func refreshLibrary() async {
        do {
            let imported = try self.persistenceService.getImportTracks()
            let downloaded = try self.persistenceService.getRecentDownloadedTracks(limit: nil)
            let playlists = try self.persistenceService.fetchPlaylists()

            let allTracks = (imported + downloaded)
                .sorted {
                    $0.songName.localizedCaseInsensitiveCompare($1.songName) == .orderedAscending
                }

            if allTracks.isNotEmpty || playlists.isNotEmpty {
                self.library = self.parseLibrary(from: allTracks, playlists: playlists)
            } else {
                self.library = nil
            }

            syncDownloadsSource(hasTracks: downloaded.isNotEmpty)
            self.ensureSections()
        } catch {
            self.handleError(error)
        }
    }

    func startObservingTracksChanges() {
        self.tracksObservationTask?.cancel()

        self.tracksObservationTask = Task { [weak self] in
            guard let self else { return }

            await self.refreshLibrary()

            self.transferViewModel.onTracksChanged = { [weak self] in
                guard let self else { return }

                Task {
                    await self.refreshLibrary()
                }
            }
        }
    }

    func stopObservingTracksChanges() {
        self.tracksObservationTask?.cancel()
        self.tracksObservationTask = nil
        self.transferViewModel.onTracksChanged = nil
    }

    func fetchfolderItems(sourceID: ImportSource.ID, path: String?) async -> [SourceFolderItem]? {
        guard let source = source(for: sourceID), let bookmarkData = source.bookmarkData else {
            let error = AppError.Source.bookmarkInvalid
            self.handleError(error)
            return nil
        }

        var isStale = false
        guard let rootURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            let error = AppError.Source.bookmarkInvalid
            self.handleError(error)
            return nil
        }

        guard rootURL.startAccessingSecurityScopedResource() else {
            let error = AppError.Source.accessDenied
            self.handleError(error)
            return nil
        }
        defer { rootURL.stopAccessingSecurityScopedResource() }

        let currentURL = path.map { rootURL.appendingPathComponent($0) } ?? rootURL

        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: currentURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

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
        } catch {
            if source.kind == .sync {
                self.handleError(AppError.Source.networkUnavailable)
            } else {
                self.handleError(AppError.Source.readFailed(error))
            }
            return nil
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

            let sourceID = source.id.uuidString

            for file in trackFiles {
                await self.importTrack(from: file, importSourceID: sourceID)
            }

            for playlistFile in playlistFiles {
                await self.importPlaylist(from: playlistFile, importSourceID: sourceID)
            }

            await self.refreshLibrary()

        } catch {
            self.handleError(error)
        }
    }

    func source(for id: ImportSource.ID) -> ImportSource? {
        self.sources.first { $0.id == id }
    }

    func libraryTracks(onlyAPI: Bool) -> [TrackEntity] {
        let filtered = onlyAPI
        ? library?.tracks.filter { $0.source == .api }
        : library?.tracks

        var seen = Set<DeduplicationKey>()

        return filtered?.filter { track in
            seen.insert(
                DeduplicationKey(
                    songName: track.songName,
                    artistName: track.artistName
                )
            ).inserted
        } ?? []
    }

    func tracksSize(_ tracks: [TrackEntity]) -> Int {
        tracks.reduce(0) { $0 + ($1.size ?? 0) }
    }

    func sourceStorageSize(for item: ImportItem) -> String? {
        guard
            case .source(let sourceID) = item,
            let source = self.source(for: sourceID)
        else {
            return nil
        }

        let tracks: [TrackEntity]

        switch source.kind {
            case .local, .sync:
                tracks = self.library?.tracks.filter {
                    $0.importSourceID == sourceID.uuidString
                } ?? []

            case .api:
                tracks = self.library?.tracks.filter {
                    $0.source == .api
                } ?? []
        }

        return self.tracksSize(tracks).formattedFileSize
    }

    func tracksDuration(_ tracks: [TrackEntity]) -> Int {
        tracks.reduce(0) { $0 + ($1.duration ?? 0) }
    }

    func isItemSelected(_ item: ImportItem) -> Bool {
        switch item {
            case .library(let libraryItem):
                return self.selectedLibraryItems.contains(libraryItem)

            case .source(let id):
                return self.selectedSourceIDs.contains(id)
        }
    }

    func toggleItem(_ item: ImportItem) {
        switch item {
            case .library(let libraryItem):
                if self.selectedLibraryItems.contains(libraryItem) {
                    self.selectedLibraryItems.remove(libraryItem)
                } else {
                    self.selectedLibraryItems.insert(libraryItem)
                }

            case .source(let id):
                if self.selectedSourceIDs.contains(id) {
                    self.selectedSourceIDs.remove(id)
                } else {
                    self.selectedSourceIDs.insert(id)
                }
        }
    }

    func moveItem(to target: ImportItem) {
        guard let from = draggingItem, from != target else { return }

        switch (from, target) {
            case (.library(let fromItem), .library(let toItem)):
                guard
                    let fromIndex = self.libraryItemsOrder.firstIndex(of: fromItem),
                    let toIndex = self.libraryItemsOrder.firstIndex(of: toItem)
                else { return }

                self.libraryItemsOrder.move(
                    fromOffsets: IndexSet(integer: fromIndex),
                    toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
                )
                self.ensureSections()

            case (.source(let fromID), .source(let toID)):
                guard
                    let fromIndex = self.sources.firstIndex(where: { $0.id == fromID }),
                    let toIndex = self.sources.firstIndex(where: { $0.id == toID })
                else { return }

                self.sources.move(
                    fromOffsets: IndexSet(integer: fromIndex),
                    toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
                )
                self.saveSources()
                self.ensureSections()

            default:
                break
        }
    }

    func sectionedTracks(from tracks: [TrackEntity]) -> [TrackAlphabetSection] {
        let grouped = Dictionary(grouping: tracks) { track -> String in
            let trimmed = track.songName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let first = trimmed.first else { return "#" }

            let letter = String(first).uppercased()
            return letter.rangeOfCharacter(from: .letters) != nil ? letter : "#"
        }

        let sortedLetters = grouped.keys.sorted { lhs, rhs in
            if lhs == "#" { return false }
            if rhs == "#" { return true }

            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        return sortedLetters.map { letter in
            TrackAlphabetSection(
                letter: letter,
                tracks: grouped[letter] ?? []
            )
        }
    }

    func beginEditSections() {
        self.isEditSectionModeEnabled = true
        self.ensureSections()
    }

    func finishEditSections() {
        self.isEditSectionModeEnabled = false
        self.draggingItem = nil
        self.saveSelectedLibraryItems()
        self.saveSelectedSourceIDs()
        self.saveLibraryItemsOrder()
        self.ensureSections()
    }

    func removeSource(_ id: ImportSource.ID) async {
        guard let source = self.sources.first(where: { $0.id == id }) else { return }

        do {
            if source.kind == .api {
                let tracks = try self.persistenceService.getRecentDownloadedTracks(limit: nil)

                for track in tracks {
                    self.transferViewModel.deleteDownloadedTrack(track: track)
                }
            } else {
                try self.persistenceService.deleteAllData(forSourceID: id.uuidString)
            }

            self.sources.removeAll { $0.id == id }
            self.selectedSourceIDs.remove(id)

            if case .source(id) = self.draggingItem {
                self.draggingItem = nil
            }

            self.saveSelectedSourceIDs()
            self.saveSources()
            await self.refreshLibrary()
        } catch {
            self.handleError(error)
        }
    }

    func dismissError() {
        self.error = nil
    }

    // MARK: - Initializer

    init() {
        self.loadLibraryItemsOrder()
        self.loadSelectedLibraryItems()
        self.loadSources()
        self.loadSelectedSourceIDs()
        self.ensureSections()
    }

    // MARK: - Properties. Private

    @Injected
    @ObservationIgnored
    private var transferViewModel: TransferManaging
    @Injected
    @ObservationIgnored
    private var persistenceService: PersistenceServicing
    private var tracksObservationTask: Task<Void, Never>?
    private let supportedPlaylistExtensions: Set<PlaylistExtension> = [.m3u, .m3u8]
    private let supportedTrackExtensions: Set<AudioFileExtension> = [.mp3, .wav, .wv, .flac]
    private enum Keys {
        static let selectedLibraryItems = "importSelectedLibraryItems"
        static let selectedSourceIDs = "importSelectedSourceIDs"
        static let libraryItemsOrder = "importLibraryItemsOrder"
        static let importSources = "importSources"
        static let downloadsSourceTitle = "Downloads"
    }

    // MARK: - Methods. Private

    private func ensureSections() {
        self.sections = [
            .init(
                kind: .library,
                items: librarySectionItems()
            ),
            .init(
                kind: .sources,
                items: sourceSectionItems()
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

    private func syncDownloadsSource(hasTracks: Bool) {
        if hasTracks {
            if self.sources.first(where: { $0.kind == .api }) != nil {
                return
            }

            let source = ImportSource(
                id: UUID(),
                kind: .api,
                title: Keys.downloadsSourceTitle,
                bookmarkData: nil
            )
            self.addOrUpdateSource(source)
        } else {
            let removedIDs = Set(sources.filter { $0.kind == .api }.map(\.id))
            self.sources.removeAll { $0.kind == .api }
            self.selectedSourceIDs.subtract(removedIDs)
            self.saveSelectedSourceIDs()
            self.saveSources()
            self.ensureSections()
        }
    }

    private func importTrack(from url: URL, importSourceID: String?, into playlist: PlaylistEntity? = nil) async {
        let ext = url.pathExtension.lowercased()

        guard
            let fileExtension = AudioFileExtension(rawValue: ext),
            self.supportedTrackExtensions.contains(fileExtension)
        else {
            return
        }

        do {
            let id = UUID().uuidString

            let metadata = try? await AudioMetadataService.extractMetadata(from: url)

            let localURL = try FileManagerService.storeImportedFile(
                from: url,
                id: id
            )
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
                releaseDate: metadata?.date ?? nil,
                download: nil,
                waveformData: nil,
                size: fileSize,
                importSourceID: importSourceID,
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

    private func importPlaylist(from url: URL, importSourceID: String?) async {
        let title = url.deletingPathExtension().lastPathComponent
        let trackURLs = self.loadPlaylist(from: url)

        guard trackURLs.isNotEmpty else { return }

        do {
            let playlist = try self.persistenceService.createPlaylist(title: title, importSourceID: importSourceID)

            for trackURL in trackURLs {
                await self.importTrack(from: trackURL, importSourceID: importSourceID, into: playlist)
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
        let directory = fileURL.deletingLastPathComponent()
        let preferredNames: Set<String> = [
            "cover.jpg", "cover.jpeg",
            "folder.jpg", "folder.jpeg",
            "Cover.jpg", "Folder.jpg"
        ]

        for name in preferredNames {
            let url = directory.appendingPathComponent(name)
            if let data = try? Data(contentsOf: url) {
                return data
            }
        }

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var preferredCandidate: URL?
        var anyJPEGCandidate: URL?

        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true { continue }

            let name = url.lastPathComponent
            let ext = url.pathExtension.lowercased()

            if preferredNames.contains(name) {
                preferredCandidate = url
                break
            }

            if anyJPEGCandidate == nil,
               ext == "jpg" || ext == "jpeg" {
                anyJPEGCandidate = url
            }
        }

        let chosen = preferredCandidate ?? anyJPEGCandidate

        return chosen.flatMap { try? Data(contentsOf: $0) }
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
                    date: tracks
                        .compactMap(\.releaseDate)
                        .first { !$0.isEmpty },
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
        guard UserDefaults.standard.object(forKey: Keys.selectedLibraryItems) != nil else {
            self.selectedLibraryItems = [.albums, .artists, .tracks, .playlists]
            return
        }

        let saved = UserDefaults.standard.stringArray(forKey: Keys.selectedLibraryItems) ?? []
        self.selectedLibraryItems = Set(saved.compactMap(LibraryItem.init(rawValue:)))
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

    private func loadSelectedSourceIDs() {
        guard UserDefaults.standard.object(forKey: Keys.selectedSourceIDs) != nil else {
            self.selectedSourceIDs = Set(sources.map(\.id))
            return
        }

        let saved = (UserDefaults.standard.array(forKey: Keys.selectedSourceIDs) as? [String]) ?? []
        self.selectedSourceIDs = Set(saved.compactMap(UUID.init(uuidString:)))

        let existing = Set(sources.map(\.id))
        self.selectedSourceIDs = self.selectedSourceIDs.intersection(existing)
    }

    private func saveSelectedSourceIDs() {
        UserDefaults.standard.set(
            selectedSourceIDs.map(\.uuidString),
            forKey: Keys.selectedSourceIDs
        )
    }

    private func addOrUpdateSource(_ source: ImportSource) {
        if let index = self.sources.firstIndex(where: { $0.title == source.title }) {
            self.sources[index] = source
        } else {
            self.sources.append(source)
            self.selectedSourceIDs.insert(source.id)
            self.saveSelectedSourceIDs()
        }
        self.saveSources()
        self.ensureSections()
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
            self.sources = []
            return
        }
        self.sources = saved
    }

    private func librarySectionItems() -> [ImportItem] {
        let all = libraryItemsOrder

        let visible = self.isEditSectionModeEnabled
        ? all
        : all.filter { self.selectedLibraryItems.contains($0) }

        return visible.map { .library($0) }
    }

    private func sourceSectionItems() -> [ImportItem] {
        let visible = self.isEditSectionModeEnabled
        ? self.sources
        : self.sources.filter { self.selectedSourceIDs.contains($0.id) }

        return visible.map { .source($0.id) }
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.error = message
        AppLogger.imported.warning("\(message)")
    }
}
