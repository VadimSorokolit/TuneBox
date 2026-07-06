//
//  PersistenceService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.05.2026.
//

import Foundation
import Combine
import SwiftData

protocol PersistenceServicing: PersistenceTrackServicing, PersistencePlaylistServicing {}

@MainActor
final class PersistenceService: PersistenceServicing {

    // MARK: - Properties. Public

    var storageDidChangePublisher: AnyPublisher<Void, Never> {
        self.storageDidChangeSubject.eraseToAnyPublisher()
    }

    // MARK: - Methods. Public

    func fetchPlaylists() throws -> [PlaylistEntity] {
        let descriptor = FetchDescriptor<PlaylistEntity>(
            sortBy: [SortDescriptor(\.title)]
        )

        return try self.modelContext.fetch(descriptor)
    }

    func getTracks() throws -> [TrackEntity] {
        do {
            let descriptor = FetchDescriptor<TrackEntity>(
                sortBy: [SortDescriptor(\.artistName),
                         SortDescriptor(\.id)
                        ]
            )

            return try self.modelContext.fetch(descriptor)
        } catch {
            AppLogger.storage.error("Failed to fetch tracks: \(error.localizedDescription)")
            throw error
        }
    }

    func getRecentsTracks(limit: Int?) throws -> [TrackEntity] {
        var descriptor = FetchDescriptor<TrackEntity>(
            sortBy: [
                SortDescriptor(\.lastStateChangeAt, order: .reverse)
            ]
        )

        if let limit {
            descriptor.fetchLimit = limit
        }

        return try modelContext.fetch(descriptor)
    }

    func getRecentDownloadedTracks(limit: Int?) throws -> [TrackEntity] {
        let completed = DownloadState.completed.rawValue
        let sourceState = TrackSource.api.rawValue

        var descriptor = FetchDescriptor<TrackEntity>(
            predicate: #Predicate<TrackEntity> { track in
                track.downloadStateRawValue == completed
                && track.sourceRawValue == sourceState
            },
            sortBy: [
                SortDescriptor(\.lastStateChangeAt, order: .reverse)
            ]
        )

        if let limit {
            descriptor.fetchLimit = limit
        }

        return try modelContext.fetch(descriptor)
    }

    func getRecentActiveTracks(limit: Int?) throws -> [TrackEntity] {
        let downloading = DownloadState.downloading.rawValue
        let queued = DownloadState.queued.rawValue
        let paused = DownloadState.paused.rawValue
        let sourceState = TrackSource.api.rawValue

        var descriptor = FetchDescriptor<TrackEntity>(
            predicate: #Predicate<TrackEntity> { track in
                (track.downloadStateRawValue == downloading && track.sourceRawValue == sourceState)
                || (track.downloadStateRawValue == queued)
                || track.downloadStateRawValue == paused
            },
            sortBy: [
                SortDescriptor(\.lastStateChangeAt, order: .reverse),
                SortDescriptor(\.id)
            ]
        )

        if let limit {
            descriptor.fetchLimit = limit
        }

        return try self.modelContext.fetch(descriptor)
    }

    func getPopularTracks() throws -> [TrackEntity] {
        do {
            let descriptor = FetchDescriptor<TrackEntity>(
                predicate: #Predicate<TrackEntity> {
                    $0.isPopular == true
                },
                sortBy: [SortDescriptor(\.artistName),
                           SortDescriptor(\.id)
                          ]
            )

            return try self.modelContext.fetch(descriptor)
        } catch {
            AppLogger.storage.error("Failed to fetch tracks: \(error.localizedDescription)")
            throw error
        }
    }

    func getTracksBy(genre: Genre?) throws -> [TrackEntity] {
        let descriptor: FetchDescriptor<TrackEntity>

        if let genre {
            let rawValue = genre.rawValue

            descriptor = FetchDescriptor<TrackEntity>(
                predicate: #Predicate<TrackEntity> {
                    $0.genreRawValue == rawValue
                },
                sortBy: [
                    SortDescriptor(\.artistName),
                    SortDescriptor(\.id)
                ]
            )
        } else {
            descriptor = FetchDescriptor<TrackEntity>(
                predicate: #Predicate<TrackEntity> {
                    $0.genreRawValue == nil
                },
                sortBy: [
                    SortDescriptor(\.artistName),
                    SortDescriptor(\.id)
                ]
            )
        }
        return try self.modelContext.fetch(descriptor)
    }

    func getSearchTracksBy(query: String, limit: Int) throws -> [TrackEntity] {
        let query = query.lowercased()

        let descriptor = FetchDescriptor<TrackEntity>(
            predicate: #Predicate<TrackEntity> {
                $0.songName.localizedStandardContains(query) ||
                $0.artistName.localizedStandardContains(query) ||
                $0.albumName.localizedStandardContains(query)
            },
            sortBy: [
                SortDescriptor(\.artistName),
                SortDescriptor(\.id)
            ]
        )

        return try self.modelContext.fetch(descriptor)
    }

    func getImportTracks() throws -> [TrackEntity] {
        let imported = TrackSource.imported.rawValue

        let descriptor = FetchDescriptor<TrackEntity>(
            predicate: #Predicate<TrackEntity> { track in
                track.sourceRawValue == imported
            },
            sortBy: [
                SortDescriptor(\.artistName),
                SortDescriptor(\.id)
            ]
        )

        return try modelContext.fetch(descriptor)
    }

    func getTrack(id: String) throws -> TrackEntity? {
        let trackID = id
        var descriptor = FetchDescriptor<TrackEntity>(
            predicate: #Predicate { $0.id == trackID }
        )
        descriptor.fetchLimit = 1

        do {
            return try self.modelContext.fetch(descriptor).first
        } catch {
            AppLogger.storage.error("Failed to fetch track \(id): \(error.localizedDescription)")
            throw error
        }
    }

    func insert(tracks entities: [TrackEntity]) throws {
        for entity in entities {
            let id = entity.id
            var descriptor = FetchDescriptor<TrackEntity>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1

            if let existing = try self.modelContext.fetch(descriptor).first {
                existing.updateMetadata(from: entity)
                existing.mergeTransferState(from: entity)
            } else {
                self.modelContext.insert(entity)
            }
        }

        do {
            try self.modelContext.save()
        } catch {
            AppLogger.storage.error("Failed to insert tracks: \(error.localizedDescription)")
            throw error
        }
    }

    func createSystemPlaylist() throws -> PlaylistEntity {
        if let existing = try self.fetchPlaylists().first(where: { $0.type == .system }) {
            return existing

        }

        let playlist = PlaylistEntity(type: PlaylistType.system, title: Constants.systemPlaylistTitle)

        self.modelContext.insert(playlist)
        try self.modelContext.save()

        print(playlist.title)
        return playlist
    }

    func createPlaylist(title: String) throws -> PlaylistEntity {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let safeName: String
        if trimmed.isEmpty {
            safeName = try self.makeDefaultPlaylistName()
        } else {
            safeName = trimmed
        }

        if self.normalizedPlaylistTitle(safeName) == self.normalizedPlaylistTitle(Constants.systemPlaylistTitle) {
            throw AppError.Storage.reservedPlaylistTitle
        }

        if try self.playlistExists(withTitle: safeName) {
            throw AppError.Storage.playlistTitleAlreadyExists
        }

        let playlist = PlaylistEntity(title: safeName)

        self.modelContext.insert(playlist)
        try self.modelContext.save()

        return playlist
    }

    func addTrack(_ track: TrackEntity, to playlist: PlaylistEntity) throws {
        guard playlist.tracks.contains(where: { $0.id == track.id }).isFalse else { return }

        playlist.tracks.append(track)

        try self.modelContext.save()
    }

    func addTracks(_ tracks: [TrackEntity], to playlist: PlaylistEntity) throws {
        for track in tracks {
            if playlist.tracks.contains(where: { $0.id == track.id }).isFalse {
                playlist.tracks.append(track)

            }
        }

        try self.modelContext.save()
    }

    func setCoverImage(_ imageData: Data?, playlist: PlaylistEntity) throws {
        guard let playlist = try self.getPlaylist(id: playlist.id) else {
            return
        }

        playlist.coverImageData = imageData

        try self.modelContext.save()
    }

    func renamePlaylist(_ playlist: PlaylistEntity, newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let safeName = trimmed.isEmpty
            ? playlist.title
            : trimmed

        if self.normalizedPlaylistTitle(safeName) == self.normalizedPlaylistTitle(Constants.systemPlaylistTitle) {
            throw AppError.Storage.reservedPlaylistTitle
        }

        if try self.playlistExists(withTitle: safeName, excluding: playlist.id) {
            throw AppError.Storage.playlistTitleAlreadyExists
        }

        playlist.title = safeName

        try self.modelContext.save()
    }

    func save() throws {
        guard self.modelContext.hasChanges else {
            return
        }

        do {
            try self.modelContext.save()
        } catch {
            AppLogger.storage.error("Failed to save context: \(error.localizedDescription)")
            throw error
        }
    }

    func delete(track: TrackEntity) throws {
        do {
            self.modelContext.delete(track)
            try self.modelContext.save()
        } catch {
            AppLogger.storage.error("Failed to delete track: \(error.localizedDescription)")
            throw error
        }
    }

    func removeTrack(_ track: TrackEntity, from playlist: PlaylistEntity) throws {
        playlist.tracks.removeAll { $0.id == track.id }

        try self.modelContext.save()
    }

    func removeTracks(from playlist: PlaylistEntity) throws {
        playlist.tracks.removeAll()

        try self.modelContext.save()
    }

    func deletePlaylist(_ playlist: PlaylistEntity) throws {
        self.modelContext.delete(playlist)

        try self.modelContext.save()
    }

    func removeCoverImage(for playlist: PlaylistEntity) throws {
        playlist.coverImageData = nil

        try self.modelContext.save()
    }

    func clearStorage() throws {
        do {
            try self.modelContext.delete(model: TrackEntity.self)
            AppLogger.storage.info("Successfully deleted all tracks")
            try self.modelContext.save()
        } catch {
            AppLogger.storage.error("Failed to delete all tracks: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Initializer

    init() throws {
        _ = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let schema = Schema([
            TrackEntity.self,
            PlaylistEntity.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])

        self.modelContainer = container
        self.modelContext = container.mainContext

        self.subscribePublishers()
    }

    // MARK: - Properties. Private

    private enum Constants {
        static let systemPlaylistTitle = "Downloaded"
        static let defaultPlaylistTitle = "New Playlist"
    }
    private let storageDidChangeSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    // MARK: - Methods. Private

    private func normalizedPlaylistTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func playlistExists(
        withTitle title: String,
        excluding playlistID: String? = nil
    ) throws -> Bool {
        let normalized = self.normalizedPlaylistTitle(title)
        return try self.fetchPlaylists().contains { playlist in
            if let playlistID, playlist.id == playlistID {
                return false
            }
            return self.normalizedPlaylistTitle(playlist.title) == normalized
        }
    }

    private func getPlaylist(id: String) throws -> PlaylistEntity? {
        let playlistID = id

        var descriptor = FetchDescriptor<PlaylistEntity>(
            predicate: #Predicate {
                $0.id == playlistID
            }
        )

        descriptor.fetchLimit = 1

        do {
            return try self.modelContext.fetch(descriptor).first
        } catch {
            AppLogger.storage.error("Failed to fetch playlist \(id): \(error.localizedDescription)")
            throw error
        }
    }

    private func makeDefaultPlaylistName() throws -> String {
        let baseName = Constants.defaultPlaylistTitle

        let playlists = try self.fetchPlaylists()

        guard playlists.contains(where: {
            self.normalizedPlaylistTitle($0.title) == self.normalizedPlaylistTitle(baseName)

        }) else {
            return baseName
        }

        var index = 2

        while playlists.contains(where: {
            self.normalizedPlaylistTitle($0.title) == normalizedPlaylistTitle("\(baseName) \(index)")
        }) {
            index += 1

        }
        return "\(baseName)\(index)"
    }

    private func subscribePublishers() {
        NotificationCenter.default
            .publisher(for: ModelContext.didSave, object: self.modelContext)
            .sink { [weak self] _ in
                self?.storageDidChangeSubject.send()
            }
            .store(in: &self.cancellables)
    }
}
