//
//  PersistenceService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.05.2026.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class PersistenceService: PersistenceServicing {

    // MARK: - Properties. Public

    var storageDidChangePublisher: AnyPublisher<Void, Never> {
        self.storageDidChangeSubject.eraseToAnyPublisher()
    }

    // MARK: - Methods. Public

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

        var descriptor = FetchDescriptor<TrackEntity>(
            predicate: #Predicate<TrackEntity> { track in
                track.downloadStateRawValue == completed
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

        var descriptor = FetchDescriptor<TrackEntity>(
            predicate: #Predicate<TrackEntity> { track in
                track.downloadStateRawValue == downloading
                || track.downloadStateRawValue == queued
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

        let schema = Schema([TrackEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])

        self.modelContainer = container
        self.modelContext = container.mainContext

        self.subscribePublishers()
    }

    // MARK: - Properties. Private

    private let storageDidChangeSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    // MARK: - Methods. Private

    private func subscribePublishers() {
        NotificationCenter.default
            .publisher(for: ModelContext.didSave, object: self.modelContext)
            .sink { [weak self] _ in
                self?.storageDidChangeSubject.send()
            }
            .store(in: &self.cancellables)
    }
}
