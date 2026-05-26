//
//  PersistenceService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.05.2026.
//

import Foundation
import Combine
import SwiftData

final class PersistenceService: PersistenceServicing {

    // MARK: - Properties. Private

    private let storageDidChangeSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    // MARK: - Initializer

    init() throws {
        let schema = Schema([TrackEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])

        self.modelContainer = container
        self.modelContext = container.mainContext

        self.subscribePublishers()
    }

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

    func insert(track entity: TrackEntity) throws {
        let id = entity.id

        var descriptor = FetchDescriptor<TrackEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

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

    private func subscribePublishers() {
        NotificationCenter.default
            .publisher(for: ModelContext.didSave, object: self.modelContext)
            .sink { [weak self] _ in
                self?.storageDidChangeSubject.send()
            }
            .store(in: &self.cancellables)
    }
}
