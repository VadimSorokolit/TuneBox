//
//  PersistenceService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.05.2026.
//

import Foundation
import SwiftData

protocol PersistenceServicing: AnyObject {
    func getTracks() throws -> [TrackEntity]
    func getTrack(id: String) throws -> TrackEntity?
    func insert(tracks: [TrackEntity]) throws
    func upsert(track: TrackEntity) throws
    func delete(track: TrackEntity) throws
    func clearStorage() throws
    func save() throws
}

final class PersistenceService: PersistenceServicing {

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init() throws {
        let schema = Schema([TrackEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])

        self.modelContainer = container
        self.modelContext = container.mainContext
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

    func getTrack(id: String) throws -> TrackEntity? {
        let trackID = id
        let descriptor = FetchDescriptor<TrackEntity>(
            predicate: #Predicate { $0.id == trackID }
        )

        do {
            return try self.modelContext.fetch(descriptor).first
        } catch {
            AppLogger.storage.error("Failed to fetch track \(id): \(error.localizedDescription)")
            throw error
        }
    }

    func insert(tracks: [TrackEntity]) throws {
        for track in tracks {
            self.modelContext.insert(track)
        }

        do {
            try self.modelContext.save()
        } catch {
            AppLogger.storage.error("Failed to insert tracks: \(error.localizedDescription)")
            throw error
        }
    }

    func upsert(track entity: TrackEntity) throws {
        let id = entity.id

        let descriptor = FetchDescriptor<TrackEntity>(
            predicate: #Predicate { $0.id == id }
        )

        if let existing = try self.modelContext.fetch(descriptor).first {
            existing.update(from: entity)
        } else {
            self.modelContext.insert(entity)
        }

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

    func clearStorage() throws {
        do {
            try self.modelContext.delete(model: TrackEntity.self)
            try self.modelContext.save()
        } catch {
            AppLogger.storage.error("Failed to delete all tracks: \(error.localizedDescription)")
            throw error
        }
    }
}
