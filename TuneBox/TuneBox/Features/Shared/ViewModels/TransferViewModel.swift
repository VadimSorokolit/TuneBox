//
//  TransferViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Foundation
import Observation

enum ReservedSpace: Int, CaseIterable {
    case oneGB = 1
    case twoGB = 2
    case fiveGB = 5

    var gigabytes: Double {
        Double(self.rawValue)
    }
}

enum Genre: String, CaseIterable, Identifiable {
    case all
    case pop
    case rock
    case jazz
    case classic
    case electronic

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

private enum SimultaneouslyLoadingCount: Int, CaseIterable {
    case two = 2
    case three = 3
    case four = 4
    case five = 5
}

@MainActor
protocol TransferManaging: AnyObject, Sendable,
    DownloadManaging,
    DownloadStateProviding,
    StorageManaging,
    PersistenceManaging {
    func getAllPersistedTracks() async -> [TrackEntity]
    func getRecentTracks(limit: Int?) async -> [TrackEntity]
    func getRecentActiveTracks(limit: Int?) async -> [TrackEntity]
    func getRecentDownloadedTracks(limit: Int?) async -> [TrackEntity]
    func loadFirstPopular() async
    func loadFirstBy(genre: Genre?) async
    func refreshBrowse(_ selectedGenre: Genre?) async
    func loadSearchBy(query: String)
    func loadNextSearch()
    func loadNextPopular()
    func loadNextBy(genre: Genre?)
    func startDownload(_ track: TrackEntity) async
    func clearSearchState()
    func cancelAllDownloads()
    func resetTransferState() async
    func saveTransferState()
    func snapshotForTerminate() async
    func handleBackgroundCompletion(_ handler: @escaping () -> Void)
    func restoreDownloadsOnForeground() async
    func handleDownloadAction(for track: TrackEntity) async
    var onTracksChanged: (() -> Void)? { get set }
}

@MainActor
@Observable
final class TransferViewModel: TransferManaging {

    // MARK: - Properties. Public

    private(set) var offsetPopular: Int = .zero
    private(set) var offsetGenre: Int = .zero
    private(set) var offsetSearch: Int = .zero
    private(set) var sections: [TracksSection] = []
    private(set) var completedSearchQuery = ""
    private(set) var inProgressTrackIDs: Set<String> = []
    private(set) var error: String?
    private(set) var simultaneouslyLoadingCount: Int = SimultaneouslyLoadingCount.two.rawValue
    private(set) var reservedSpace: ReservedSpace = .oneGB
    private(set) var isRefreshing = false
    private(set) var isPopularFirstLoading = false
    private(set) var isPaginationPopularLoading = false
    private(set) var isPaginationSearchLoading = false
    private(set) var isGenreFirstLoading = false
    private(set) var isPaginationGenreLoading = false
    private(set) var isSearchLoading = false
    private(set) var reachedPopularTracksEnd = false
    private(set) var reachedGenreTracksEnd = false
    private(set) var reachedSearchTracksEnd = false

    var selectedGenre: Genre = .all
    @ObservationIgnored
    var onTracksChanged: (() -> Void)?

    var inProgressTracksCount: Int {
        self.inProgressTrackIDs.count
    }

    var isFetchTracks: Bool {
        self.fetchTracksCount > .zero
    }

    var shouldShowCentralSpinner: Bool {
        (self.isPopularFirstLoading && self.tracks(for: .popular).isEmpty && self.isRefreshing.isFalse)
        || (self.isGenreFirstLoading && self.tracks(for: .genre).isEmpty && self.isRefreshing.isFalse)
        || self.isSearchLoading
        || self.isFetchTracks
    }

    var availableSpace: Double? {
        self.storageService.getFreeStorage()
    }

    // MARK: - Methods. Public

    func loadFirstPopular() async {
        self.reachedPopularTracksEnd = false

        self.isPopularFirstLoading = true

        defer {
            self.isPopularFirstLoading = false
        }

        do {
            let persistedEntities = try self.persistenceService.getPopularTracks()
            try Task.checkCancellation()

            if persistedEntities.isEmpty || self.isRefreshing {
                try await self.loadPopularInitialTracks()
            } else {
                self.set(persistedEntities, for: .popular)
                self.offsetPopular = persistedEntities.count

                await self.restoreFromPersistedState(self.tracks(for: .popular))
            }
        } catch is CancellationError {
            AppLogger.network.debug("Load cancelled")
        } catch {
            self.handleError(error)
        }
    }

    func loadNextPopular() {
        guard self.isPaginationPopularLoading == false,
              self.reachedPopularTracksEnd == false else {
            return
        }

        self.popularLoadTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.isPaginationPopularLoading = true

            defer {
                self.isPaginationPopularLoading = false
                self.popularLoadTask = nil
            }

            let newTracks = await self.loadPopularTracks(offset: self.offsetPopular)

            if newTracks.count < self.limit {
                self.reachedPopularTracksEnd = true
            }

            guard newTracks.isNotEmpty else {
                return
            }

            self.mergeTracks(newTracks, for: .popular)
            self.offsetPopular += newTracks.count
        }
    }

    func loadFirstBy(genre: Genre?) async {
        self.reachedGenreTracksEnd = false

        self.cancelGenreLoadTask()

        let selectedGenre = genre ?? .all

        self.selectedGenre = selectedGenre
        self.isGenreFirstLoading = true

        defer {
            self.isGenreFirstLoading = false
            self.genreLoadTask = nil
        }

        do {
            let persistedEntities = try self.persistenceService.getTracksBy(genre: selectedGenre)
            try Task.checkCancellation()

            if persistedEntities.isEmpty || self.isRefreshing {
                try await self.loadGenreInitialTracks(genre: selectedGenre)
            } else {
                self.set(persistedEntities, for: .genre)
                self.offsetGenre = persistedEntities.count

                await self.restoreFromPersistedState(self.tracks(for: .genre))
            }
        } catch is CancellationError {
            AppLogger.network.debug("Load cancelled")
        } catch {
            self.handleError(error)
        }
    }

    func loadNextBy(genre: Genre?) {
        guard self.isPaginationGenreLoading == false,
              self.reachedGenreTracksEnd == false else {
            return
        }

        let resolvedGenre = genre ?? self.selectedGenre
        self.selectedGenre = resolvedGenre
        let apiGenre = self.apiGenre(for: resolvedGenre)

        self.genreLoadTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.isPaginationGenreLoading = true

            defer {
                self.isPaginationGenreLoading = false
                self.genreLoadTask = nil
            }

            let newTracks = await self.loadTracksBy(
                genre: apiGenre,
                offset: self.offsetGenre,
                appendToGenreTracks: true
            )

            if newTracks.count < self.limit {
                self.reachedGenreTracksEnd = true
            }
        }
    }

    func refreshBrowse(_ selectedGenre: Genre?) async {
        self.isRefreshing = true

        defer { self.isRefreshing = false }

        async let popular = self.loadFirstPopular()
        async let genre = self.loadFirstBy(genre: selectedGenre == .all ? nil : selectedGenre)

        _ = await (popular, genre)
    }

    func loadSearchBy(query: String) {
        self.reachedSearchTracksEnd = false
        self.offsetSearch = .zero
        self.cancelSearchLoadTask()

        guard query.count > 2 else {
            self.isSearchLoading = false
            return
        }

        self.isSearchLoading = true

        self.searchLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            defer {
                self.isSearchLoading = false
                self.searchLoadTask = nil
            }

            do {
                let dtos = try await self.networkService.searchTracks(
                    query: query,
                    limit: self.limit,
                    offset: .zero
                )

                try Task.checkCancellation()

                let resolved = self.upsertAndResolve(dtos.map(TrackEntity.init))

                self.set(resolved, for: .search)
                self.completedSearchQuery = query
                self.offsetSearch = resolved.count
                self.reachedSearchTracksEnd = resolved.count < self.limit
            } catch is CancellationError {
                AppLogger.network.debug("Search cancelled")
            } catch {
                self.handleError(error)
            }
        }
    }

    func loadNextSearch() {
        guard self.isPaginationSearchLoading == false,
              self.reachedSearchTracksEnd == false else {
            return
        }

        guard self.completedSearchQuery.count > 2 else {
            return
        }

        self.searchLoadTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.isPaginationSearchLoading = true

            defer {
                self.isPaginationSearchLoading = false
                self.searchLoadTask = nil
            }

            do {
                let dtos = try await self.networkService.searchTracks(
                    query: self.completedSearchQuery,
                    limit: self.limit,
                    offset: self.offsetSearch
                )

                let entities = dtos.map(TrackEntity.init)
                let resolved = self.upsertAndResolve(entities)

                if resolved.count < self.limit {
                    self.reachedSearchTracksEnd = true
                }

                self.mergeTracks(resolved, for: .search)
                self.offsetSearch += resolved.count
            } catch is CancellationError {
                AppLogger.network.debug("Search pagination cancelled")
            } catch {
                self.handleError(error)
            }
        }
    }

    func getAllPersistedTracks() async -> [TrackEntity] {
        self.startFetchTracks()

        defer {
            self.finishFetchTracks()
        }

        do {
            let tracks: [TrackEntity] = try self.persistenceService.getTracks()
            return tracks
        } catch {
            self.handleError(error)
            return []
        }
    }
    
    func getRecentTracks(limit: Int?) async -> [TrackEntity] {
        self.startFetchTracks()
        
        defer {
            self.finishFetchTracks()
        }
        
        do {
            let tracks = try self.persistenceService.getRecentsTracks(limit: limit)
            return tracks
        } catch {
            self.handleError(error)
            return []
        }
    }

    func getRecentActiveTracks(limit: Int?) async -> [TrackEntity] {
        self.startFetchTracks()

        defer {
            self.finishFetchTracks()
        }

        do {
            let tracks = try self.persistenceService.getRecentActiveTracks(limit: limit)
            return tracks
        } catch {
            self.handleError(error)
            return []
        }
    }

    func getRecentDownloadedTracks(limit: Int?) async -> [TrackEntity] {
        self.startFetchTracks()

        defer {
            self.finishFetchTracks()
        }

        do {
            let tracks = try self.persistenceService.getRecentDownloadedTracks(limit: limit)
            return tracks
        } catch {
            self.handleError(error)
            return []
        }
    }

    func startDownload(_ track: TrackEntity) async {
        let track = self.ensureCanonical(track)

        guard self.hasEnoughFreeSpace(for: track) else {
            return
        }

        if track.downloadingSize != .zero {
            await self.resumeDownload(track: track)
            return
        }

        guard self.hasFreeDownloadSlot else {
            self.enqueueDownload(track: track)
            return
        }

        await self.activateDownload(track: track)
    }

    func stopDownload(track: TrackEntity) async {
        let track = self.ensureCanonical(track)

        await self.networkService.stopDownload(trackId: track.id)
        await self.finishActiveDownload(trackId: track.id)

        self.setTransferState(
            for: track.id,
            downloadState: .paused,
            fileState: .exists
        )

        self.logTransferWarning("Paused track \(track.id): \(self.formatBytes(track.downloadingSize))")
    }

    func resumeDownload(track: TrackEntity) async {
        let track = self.ensureCanonical(track)

        guard self.hasEnoughFreeSpace(for: track) else {
            return
        }

        guard self.hasFreeDownloadSlot else {
            self.enqueueDownload(track: track)
            return
        }

        await self.activateResumeDownload(track: track)
    }

    func clearSearchState() {
        self.cancelSearchLoadTask()
        self.reachedSearchTracksEnd = false
        self.set([], for: .search)
        self.offsetSearch = .zero
        self.isSearchLoading = false
        self.completedSearchQuery = ""
    }

    func cancelQueuedDownload(track: TrackEntity) {
        let track = self.ensureCanonical(track)

        guard track.downloadState == .queued else {
            return
        }

        self.queuedDownloadTrackIDs.removeAll { $0 == track.id }
        self.resetTrackState(track, to: .idle, fileState: FileStorageState.none)
        self.persistDownloadSession()
    }

    func saveTransferState() {
        self.persistDownloadSession(force: true)
    }

    func snapshotForTerminate() async {
        self.saveTransferState()
        await self.networkService.snapshotResumeDataForRelaunch()
    }

    func cancelAllDownloads() {
        Task {
            await self.networkService.cancelAllDownloads()
        }
        self.inProgressTrackIDs.removeAll()
        self.queuedDownloadTrackIDs.removeAll()

        for track in self.allTracks {
            switch track.downloadState {
                case .downloading,
                        .queued,
                        .paused,
                        .failed:

                    self.resetTrackState(track, to: .idle, fileState: FileStorageState.none)

                case .completed,
                        .idle:

                    break
            }
        }

        self.persistDownloadSession(force: true)
    }

    func restoreDownloadsOnForeground() async {
        await self.networkService.restoreDownloadSession()
        let runningTrackIDs = await self.networkService.runningDownloadTrackIDs()

        for trackID in runningTrackIDs {
            self.inProgressTrackIDs.insert(trackID)

            if let track = self.track(byID: trackID), track.downloadState != .downloading {
                self.setTransferState(
                    for: trackID,
                    downloadState: .downloading
                )
            }
        }

        await self.processDownloadQueue()
    }

    func deleteDownloadedTrack(track: TrackEntity) {
        let track = self.ensureCanonical(track)

        self.networkService.clearPersistedResumeData(trackId: track.id)

        if AudioService.shared.currentTrackId == track.id {
            AudioService.shared.stop()
        }

        do {
            try self.storageService.deleteDownloadedTrack(id: track.id)
            self.resetTrackState(track, to: .idle, fileState: .removed)
        } catch {
            self.handleError(error)
        }
    }

    func setSimultaneouslyLoadingLimit(_ limit: Int) {
        self.simultaneouslyLoadingCount = limit

        Task { @MainActor [weak self] in
            await self?.processDownloadQueue()
        }
    }

    func applyReservedSpace(_ plan: ReservedSpace) {
        do {
            try self.storageService.checkEnoughFreeStorage(requiredGB: plan.gigabytes)
            self.reservedSpace = plan
        } catch {
            self.handleError(error)
        }
    }

    func handleBackgroundCompletion(_ handler: @escaping () -> Void) {
        self.networkService.setBackgroundCompletionHandler { [weak self] in
            Task { @MainActor in
                self?.persistDownloadSession(force: true)
                handler()
            }
        }
    }

    func handleDownloadAction(for track: TrackEntity) async {
        let track = self.ensureCanonical(track)

        switch track.downloadState {
            case .idle:
                await self.startDownload(track)

            case .paused:
                await self.resumeDownload(track: track)

            case .downloading:
                await self.stopDownload(track: track)

            case .completed:
                self.deleteDownloadedTrack(track: track)

            case .queued:
                self.cancelQueuedDownload(track: track)

            case .failed:
                self.error = nil
                await self.startDownload(track)
        }
    }

    // MARK: - Only for testing!!!

    func resetTransferState() async {
        self.cancelPopularLoadTask()
        self.cancelGenreLoadTask()
        self.cancelSearchLoadTask()

        await self.networkService.cancelAllDownloads()

        self.queuedDownloadTrackIDs.removeAll()
        self.inProgressTrackIDs.removeAll()

        AudioService.shared.stop()
        self.clearDownloadState()
        self.sections.removeAll()

        do {
            try self.persistenceService.clearStorage()
            try self.storageService.clearStorage()

            self.offsetPopular = .zero
            self.offsetGenre = .zero
            self.offsetSearch = .zero
        } catch {
            self.handleError(error)
        }

        self.onTracksChanged?()
    }

    // MARK: - Initializer

    init(
        networkService: NetworkServicing,
        persistenceService: PersistenceServicing,
        storageService: FileManagerServicing
    ) {
        self.networkService = networkService
        self.persistenceService = persistenceService
        self.storageService = storageService

        self.setupNotificationObservers()
    }

    // MARK: - Properties. Private

    /**
     Private implementation details don't need to be observed from outside.
     Use `@ObservationIgnored` for mutable private properties that should not trigger view updates.
     Note: `@Observable` already skips `let` constants automatically.
     */

    private let limit: Int = 30
    private let networkService: NetworkServicing
    private let persistenceService: PersistenceServicing
    private let storageService: FileManagerServicing
    private let downloadObserverTokens = TransferDownloadObserverTokens()
    private var fetchTracksCount: Int = .zero

    @ObservationIgnored
    private var queuedDownloadTrackIDs: [String] = []
    @ObservationIgnored
    private var lastPersistedProgressBytesByTrackID: [String: Int] = [:]
    @ObservationIgnored
    private var popularLoadTask: Task<Void, Never>?
    @ObservationIgnored
    private var genreLoadTask: Task<Void, Never>?
    @ObservationIgnored
    private var searchLoadTask: Task<Void, Never>?
    @ObservationIgnored
    private var isProcessingDownloadQueue = false
    @ObservationIgnored
    private var pendingDownloadQueuePass = false

    private let progressPersistStepBytes = 65_536
    private let estimatedTrackSizeFallback: Int = 10 * 1024 * 1024

    private var hasFreeDownloadSlot: Bool {
        self.inProgressTrackIDs.count < self.simultaneouslyLoadingCount
    }

    private var allTracks: [TrackEntity] {
        self.sections.flatMap(\.tracks)
    }

    // MARK: - Methods. Private

    private func set(
        _ tracks: [TrackEntity],
        for type: TracksSection.SectionType
    ) {
        if let index = self.sections.firstIndex(where: { $0.type == type }) {
            self.sections[index].tracks = tracks
        } else {
            self.sections.append(
                TracksSection(
                    type: type,
                    tracks: tracks
                )
            )
        }
    }

    private func startFetchTracks() {
        self.fetchTracksCount += 1
    }

    private func finishFetchTracks() {
        self.fetchTracksCount = max(.zero, self.fetchTracksCount - 1)
    }

    private func cancelPopularLoadTask() {
        self.popularLoadTask?.cancel()
        self.popularLoadTask = nil
    }

    private func cancelGenreLoadTask() {
        self.genreLoadTask?.cancel()
        self.genreLoadTask = nil
    }

    private func cancelSearchLoadTask() {
        self.searchLoadTask?.cancel()
        self.searchLoadTask = nil
    }

    private func loadPopularInitialTracks() async throws {
        let offsetZero: Int = .zero

        let loadedTracks = await self.loadPopularTracks(offset: offsetZero)
        try Task.checkCancellation()

        self.offsetPopular = offsetZero

        if self.tracks(for: .popular).isEmpty {
            self.set(loadedTracks, for: .popular)
        } else {
            self.mergeTracks(loadedTracks, for: .popular)
        }
        self.offsetPopular = self.tracks(for: .popular).count
        self.reachedPopularTracksEnd = (loadedTracks.count < self.limit)
    }

    private func loadGenreInitialTracks(genre: Genre) async throws {
        let offsetZero: Int = .zero

        let loadedTracks = await self.loadTracksBy(
            genre: self.apiGenre(for: genre),
            offset: offsetZero,
            appendToGenreTracks: false
        )
        try Task.checkCancellation()

        self.offsetGenre = offsetZero

        self.set(loadedTracks, for: .genre)

        self.offsetGenre = self.tracks(for: .genre).count
        self.reachedGenreTracksEnd = (loadedTracks.count < self.limit)
    }

    private func apiGenre(for genre: Genre) -> Genre? {
        genre == .all ? nil : genre
    }

    private func restoreFromPersistedState(_ tracks: [TrackEntity]) async {
        self.seedPersistedProgressBaseline(tracks)

        await self.networkService.restoreDownloadSession()
        await self.networkService.waitForPendingCancellations(timeout: 2.5)
        await self.restoreInterruptedDownloads(tracks)
        await self.processDownloadQueue()
    }

    private func loadPopularTracks(offset: Int) async -> [TrackEntity] {
        do {
            let dtos = try await self.networkService.getPopularTracks(
                limit: self.limit,
                offset: offset
            )

            let entities = dtos.map(TrackEntity.init)

            entities.forEach {
                $0.isPopular = true
            }

            return self.upsertAndResolve(entities)
        } catch {
            self.handleError(error)

            return []
        }
    }

    private func loadTracksBy(
        genre: Genre?,
        offset: Int,
        appendToGenreTracks: Bool
    ) async -> [TrackEntity] {
        do {
            let dtos = try await self.networkService.getTracksByGenre(
                genre: genre?.displayName,
                limit: self.limit,
                offset: offset
            )

            let entities = dtos.map(TrackEntity.init)

            if let genre {
                entities.forEach {
                    $0.genre = genre
                }
            } else {
                entities.forEach {
                    $0.genre = .all
                }
            }

            let resolved = self.upsertAndResolve(entities)

            if appendToGenreTracks {
                self.mergeTracks(resolved, for: .genre)
                self.offsetGenre += resolved.count
            }

            return resolved
        } catch {
            self.handleError(error)
            return []
        }
    }

    @discardableResult
    private func upsertAndResolve(_ entities: [TrackEntity]) -> [TrackEntity] {
        guard entities.isEmpty == false else {
            return []
        }

        do {
            try self.persistenceService.insert(tracks: entities)
        } catch {
            self.handleError(error)
            return entities
        }

        let resolved = entities.map { entity in
            self.fetchCanonicalTrack(id: entity.id) ?? entity
        }

        for track in resolved {
            self.replaceWithCanonical(track)
        }

        return resolved
    }

    private func ensureCanonical(_ track: TrackEntity) -> TrackEntity {
        if let existing = self.fetchCanonicalTrack(id: track.id) {
            self.replaceWithCanonical(existing)
            return existing
        }

        return self.upsertAndResolve([track]).first ?? track
    }

    private func fetchCanonicalTrack(id: String) -> TrackEntity? {
        do {
            return try self.persistenceService.getTrack(id: id)
        } catch {
            self.handleError(error)
            return nil
        }
    }

    private func replaceWithCanonical(_ canonical: TrackEntity) {
        for index in self.sections.indices {
            self.replaceInList(&self.sections[index].tracks, with: canonical)
        }
    }

    private func replaceInList(_ list: inout [TrackEntity], with canonical: TrackEntity) {
        for index in list.indices where list[index].id == canonical.id {
            self.assignCanonical(&list[index], canonical: canonical)
        }
    }

    private func mergeTracks(
        _ incoming: [TrackEntity],
        for type: TracksSection.SectionType
    ) {
        guard let sectionIndex = self.sections.firstIndex(where: { $0.type == type }) else {
            self.set(incoming, for: type)
            return
        }

        for incomingTrack in incoming {
            if let trackIndex = self.sections[sectionIndex].tracks.firstIndex(where: { $0.id == incomingTrack.id }) {
                self.assignCanonical(
                    &self.sections[sectionIndex].tracks[trackIndex],
                    canonical: incomingTrack
                )
            } else {
                self.sections[sectionIndex].tracks.append(incomingTrack)
            }
        }
    }

    /// Replaces a list slot with the SwiftData canonical instance, preserving the stronger transfer snapshot.
    private func assignCanonical(_ slot: inout TrackEntity, canonical: TrackEntity) {
        guard slot !== canonical else {
            return
        }

        canonical.mergeTransferState(from: slot)
        slot = canonical
    }

    private func updateTracks(withID trackID: String, _ update: (TrackEntity) -> Void) {
        var visited = Set<ObjectIdentifier>()

        for track in self.allTracks where track.id == trackID {
            let identifier = ObjectIdentifier(track)

            guard visited.insert(identifier).inserted else {
                continue
            }

            update(track)
        }
    }

    private func setTransferState(
        for trackID: String,
        downloadState: DownloadState,
        fileState: FileStorageState? = nil,
        downloadingSize: Int? = nil,
        lastStateChangeAt: Date = Date()
    ) {
        self.updateTracks(withID: trackID) { track in
            track.downloadState = downloadState
            track.lastStateChangeAt = lastStateChangeAt

            if let downloadingSize {
                track.downloadingSize = downloadingSize
            }

            if let fileState {
                track.fileState = fileState
            }
        }

        self.onTracksChanged?()
    }

    private func delete(_ tracks: [TrackEntity]) {
        for track in tracks {
            do {
                try self.persistenceService.delete(track: track)
            } catch {
                self.handleError(error)
            }
        }
    }

    private func enqueueDownload(track: TrackEntity) {
        let track = self.ensureCanonical(track)

        guard self.queuedDownloadTrackIDs.contains(track.id) == false else {
            return
        }

        self.queuedDownloadTrackIDs.append(track.id)
        self.setTransferState(
            for: track.id,
            downloadState: .queued
        )
        self.persistDownloadSession()
    }

    private func activateDownload(track: TrackEntity) async {
        self.inProgressTrackIDs.insert(track.id)
        self.setTransferState(
            for: track.id,
            downloadState: .downloading
        )
        self.updateProgressBaseline(for: track)
        self.persistDownloadSession()

        do {
            try await self.networkService.startDownload(track)
        } catch {
            await self.handleDownloadActivationFailure(track, error: error)
        }
    }

    private func tracks(for type: TracksSection.SectionType) -> [TrackEntity] {
        self.sections.first { $0.type == type }?.tracks ?? []
    }

    private func activateResumeDownload(track: TrackEntity) async {
        self.inProgressTrackIDs.insert(track.id)
        self.setTransferState(
            for: track.id,
            downloadState: .downloading
        )
        self.updateProgressBaseline(for: track)
        self.persistDownloadSession()

        do {
            try await self.networkService.resumeDownload(trackId: track.id)
        } catch {
            await self.handleResumeFailure(track, error: error)
        }
    }

    private func handleDownloadActivationFailure(_ track: TrackEntity, error: Error) async {
        self.markDownloadFailed(track: track)
        self.handleError(error)
        await self.finishActiveDownload(trackId: track.id)
    }

    private func handleResumeFailure(_ track: TrackEntity, error: Error) async {
        self.logTransferWarning("Resume failed for \(track.id), restarting from scratch: \(error.localizedDescription)")
        self.networkService.clearPersistedResumeData(trackId: track.id)

        do {
            try await self.networkService.startDownload(track)
        } catch {
            await self.handleDownloadActivationFailure(track, error: error)
        }
    }

    private func finishActiveDownload(trackId: String) async {
        self.inProgressTrackIDs.remove(trackId)
        self.persistDownloadSession()
        await self.processDownloadQueue()
    }

    private func processDownloadQueue() async {
        guard self.isProcessingDownloadQueue == false else {
            self.pendingDownloadQueuePass = true
            return
        }

        self.isProcessingDownloadQueue = true

        defer {
            self.isProcessingDownloadQueue = false
        }

        repeat {
            self.pendingDownloadQueuePass = false

            let runningTrackIDs = await self.networkService.runningDownloadTrackIDs()

            while self.hasFreeDownloadSlot, self.queuedDownloadTrackIDs.isEmpty == false {
                let trackID = self.queuedDownloadTrackIDs.removeFirst()

                guard runningTrackIDs.contains(trackID) == false,
                      self.inProgressTrackIDs.contains(trackID) == false,
                      let track = self.track(byID: trackID),
                      track.downloadState == .queued else {
                    continue
                }

                guard self.hasEnoughFreeSpace(for: track) else {
                    self.resetTrackState(track, to: .idle)
                    continue
                }

                let hasResumeData = await self.networkService.hasPersistedResumeData(trackId: trackID)

                if hasResumeData {
                    await self.activateResumeDownload(track: track)
                } else {
                    await self.activateDownload(track: track)
                }

                self.persistDownloadSession()
            }
        } while self.pendingDownloadQueuePass
    }

    private func restoreInterruptedDownloads(_ tracks: [TrackEntity]) async {
        let liveActive = await self.networkService.runningDownloadTrackIDs()

        for track in self.uniqueTracksByID(tracks)
        where self.storageService.downloadedTrackExists(id: track.id) {
            self.setTransferState(
                for: track.id,
                downloadState: .completed,
                fileState: .exists,
                downloadingSize: track.size ?? track.downloadingSize
            )
        }

        var queuedInOrder: [String] = []
        var queuedIDs = Set<String>()

        for track in self.uniqueTracksByID(self.allTracks)
        where track.downloadState == .downloading && liveActive.contains(track.id) {
            self.inProgressTrackIDs.insert(track.id)
        }

        for track in self.uniqueTracksByID(self.allTracks)
        where track.downloadState == .downloading && liveActive.contains(track.id) == false {
            self.setTransferState(
                for: track.id,
                downloadState: .queued
            )

            if queuedIDs.insert(track.id).inserted {
                queuedInOrder.append(track.id)
            }
        }

        let persistedQueue = self.uniqueTracksByID(self.allTracks)
            .filter { $0.downloadState == .queued }
            .sorted { ($0.downloadQueueIndex ?? .max) < ($1.downloadQueueIndex ?? .max) }

        for track in persistedQueue where queuedIDs.insert(track.id).inserted {
            queuedInOrder.append(track.id)
        }

        self.queuedDownloadTrackIDs = queuedInOrder
        self.persistDownloadSession(force: true)
    }

    private func persistDownloadSession(force: Bool = false) {
        let queuePositionByTrackID = Dictionary(
            uniqueKeysWithValues: self.queuedDownloadTrackIDs.enumerated().map { ($1, $0) }
        )

        var indicesChanged = false

        for track in self.allTracks {
            let newPosition = queuePositionByTrackID[track.id]
            if track.downloadQueueIndex != newPosition {
                track.downloadQueueIndex = newPosition
                indicesChanged = true
            }
        }

        guard force || indicesChanged else {
            return
        }

        do {
            try self.persistenceService.save()
        } catch {
            self.handleError(error)
        }
    }

    private func seedPersistedProgressBaseline(_ tracks: [TrackEntity]) {
        for track in tracks where track.downloadState == .downloading {
            self.updateProgressBaseline(for: track)
        }
    }

    private func updateProgressBaseline(for track: TrackEntity) {
        self.lastPersistedProgressBytesByTrackID[track.id] = track.downloadingSize
    }

    private func hasEnoughFreeSpace(for track: TrackEntity) -> Bool {
        let size = track.size ?? self.estimatedTrackSizeFallback
        let requiredGB = Double(size) / GlobalConstants.bytesInGigabyte
        let available = self.storageService.getFreeStorage() ?? .zero
        let reserved = self.reservedSpace.gigabytes

        guard available >= requiredGB else {
            let message = "Not enough free space on device"
            self.error = message
            self.logTransferWarning(message)
            return false
        }

        guard (available - requiredGB) >= reserved else {
            let message = "Download would violate reserved space policy (reserved: \(reserved) GB)"
            self.error = message
            self.logTransferWarning(message)
            return false
        }

        return true
    }

    private func applyDownloadProgress(trackID: String, totalBytesWritten: Int64) {
        guard let track = self.track(byID: trackID) else {
            return
        }

        let reportedBytes = Int(min(totalBytesWritten, Int64(Int.max)))
        let displayedBytes = max(track.downloadingSize, reportedBytes)

        self.updateTracks(withID: trackID) { listedTrack in
            listedTrack.downloadingSize = displayedBytes
        }

        self.onTracksChanged?()

        guard track.downloadState == .downloading else {
            return
        }

        let lastPersisted = self.lastPersistedProgressBytesByTrackID[trackID] ?? .zero
        let shouldPersist = (displayedBytes - lastPersisted) >= self.progressPersistStepBytes
            || displayedBytes == track.size

        guard shouldPersist else {
            return
        }

        self.lastPersistedProgressBytesByTrackID[trackID] = displayedBytes
    }

    private func applyDownloadFinished(trackID: String) {
        guard let track = self.track(byID: trackID) else {
            return
        }

        self.setTransferState(
            for: trackID,
            downloadState: .completed,
            fileState: .exists,
            downloadingSize: track.size ?? .zero
        )

        Task { @MainActor [weak self] in
            await self?.finishActiveDownload(trackId: trackID)
        }
    }

    private func applyDownloadFailed(trackID: String, error: Any) {
        guard let track = self.track(byID: trackID) else {
            return
        }

        self.markDownloadFailed(track: track)

        let resolvedError: Error = {
            if let apiError = error as? AppError.API {
                return apiError
            }
            if let localizedError = error as? Error {
                return localizedError
            }
            return AppError.API.unknown
        }()
        self.handleError(resolvedError)

        Task { @MainActor [weak self] in
            await self?.finishActiveDownload(trackId: trackID)
        }
    }

    private func applyDownloadInterrupted(trackID: String) async {
        self.inProgressTrackIDs.remove(trackID)

        guard let track = self.track(byID: trackID) else {
            self.persistDownloadSession()
            await self.processDownloadQueue()
            return
        }

        if track.downloadState == .paused {
            self.persistDownloadSession()
            await self.processDownloadQueue()
            return
        }

        if self.queuedDownloadTrackIDs.contains(trackID) == false {
            self.queuedDownloadTrackIDs.insert(trackID, at: .zero)
        }
        self.setTransferState(
            for: trackID,
            downloadState: .queued
        )

        self.persistDownloadSession()
        await self.processDownloadQueue()
    }

    private func track(byID trackID: String) -> TrackEntity? {
        if let canonical = self.fetchCanonicalTrack(id: trackID) {
            return canonical
        }

        return self.allTracks.first { $0.id == trackID }
    }

    private func uniqueTracksByID(_ tracks: [TrackEntity]) -> [TrackEntity] {
        var seen = Set<String>()
        var unique: [TrackEntity] = []

        for track in tracks {
            guard seen.insert(track.id).inserted else {
                continue
            }

            unique.append(track)
        }

        return unique
    }

    private func resetTrackState(
        _ track: TrackEntity,
        to state: DownloadState,
        fileState: FileStorageState? = nil,
        lastStateChangeAt: Date = Date()
    ) {
        self.updateTracks(withID: track.id) { listedTrack in
            listedTrack.downloadState = state
            listedTrack.downloadingSize = .zero
            listedTrack.lastStateChangeAt = lastStateChangeAt

            if let fileState {
                listedTrack.fileState = fileState
            }
        }

        self.onTracksChanged?()
    }

    private func clearDownloadState() {
        for track in self.allTracks {
            self.resetTrackState(track, to: .idle)
        }
    }

    private func markDownloadFailed(track: TrackEntity) {
        self.resetTrackState(track, to: .failed, fileState: FileStorageState.none)
    }

    private func formatBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func logTransferWarning(_ message: String) {
        AppLogger.transfer.warning("\(message)")
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        self.error = message
        self.logTransferWarning(message)
    }

    private func setupNotificationObservers() {
        let mainQueue = OperationQueue.main

        self.downloadObserverTokens.progressToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadProgress,
            object: nil,
            queue: mainQueue
        ) { [weak self] notification in
            guard
                let trackID: String = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.trackID
                ),
                let trackDownloadedBytes: Int64 = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.totalBytesWritten
                )
            else {
                return
            }

            guard let self else { return }

            Task { @MainActor in
                self.applyDownloadProgress(trackID: trackID, totalBytesWritten: trackDownloadedBytes)
            }
        }

        self.downloadObserverTokens.finishedToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadDidFinish,
            object: nil,
            queue: mainQueue
        ) { [weak self] notification in
            guard
                let trackID: String = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.trackID
                )
            else {
                return
            }

            guard let self else { return }

            Task { @MainActor in
                self.applyDownloadFinished(trackID: trackID)
            }
        }

        self.downloadObserverTokens.failedToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadDidFail,
            object: nil,
            queue: mainQueue
        ) { [weak self] notification in
            guard
                let trackID: String = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.trackID
                ),
                let error: Error = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.error
                )
            else {
                return
            }

            guard let self else { return }

            Task { @MainActor in
                self.applyDownloadFailed(trackID: trackID, error: error)
            }
        }

        self.downloadObserverTokens.interruptedToken = NotificationCenter.default.addObserver(
            forName: .trackDownloadDidInterrupt,
            object: nil,
            queue: mainQueue
        ) { [weak self] notification in
            guard
                let trackID: String = notification.value(
                    for: TrackDownloadNotificationUserInfoKey.trackID
                )
            else {
                return
            }

            Task { @MainActor in
                await self?.applyDownloadInterrupted(trackID: trackID)
            }
        }
    }
}
