//
//  PersistenceService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.05.2026.
//

import Foundation
import SwiftData

protocol PersistenceServicing {
    func getTracks() throws -> [TrackEntity]
    func upsert(track: TrackEntity) throws
    func delete(track: TrackEntity) throws
    func deleteAll() throws
}

final class PersistenceService: PersistenceServicing {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getTracks() throws -> [TrackEntity] {
        do {
            let descriptor = FetchDescriptor<TrackEntity>(
                sortBy: [SortDescriptor(\.artistName)]
            )

            return try self.modelContext.fetch(descriptor)
        } catch {
            AppLogger.storage.error("Failed to fetch tracks: \(error.localizedDescription)")
            throw error
        }
    }

    func upsert(track: TrackEntity) throws {
        do {
            let id = track.id

            let descriptor = FetchDescriptor<TrackEntity>(
                predicate: #Predicate<TrackEntity> { track in
                    track.id == id
                }
            )

            if let existing = try modelContext.fetch(descriptor).first {
                existing.image = track.image
                existing.trackName = track.trackName
                existing.artistName = track.artistName
                existing.albumName = track.albumName
                existing.releaseDate = track.releaseDate
                existing.download = track.download
                existing.size = track.size
                existing.isDownloaded = track.isDownloaded
                existing.downloadingSize = track.downloadingSize
            } else {
                modelContext.insert(track)
            }

            try modelContext.save()

        } catch {
            AppLogger.storage.error("Upsert failed: \(error.localizedDescription)")
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

    func deleteAll() throws {
        do {
            try self.modelContext.delete(model: TrackEntity.self)
            try self.modelContext.save()
        } catch {
            AppLogger.storage.error("Failed to delete all tracks: \(error.localizedDescription)")
            throw error
        }
    }
}
