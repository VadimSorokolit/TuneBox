//
//  PersistenceServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation
import Combine

protocol PersistenceServicing: AnyObject {
    var storageDidChangePublisher: AnyPublisher<Void, Never> { get }

    func getTracks() throws -> [TrackEntity]
    func getRecentsTracks(limit: Int?) throws -> [TrackEntity]
    func getRecentActiveTracks(limit: Int?) throws -> [TrackEntity]
    func getRecentDownloadedTracks(limit: Int?) throws -> [TrackEntity]
    func getPopularTracks() throws -> [TrackEntity]
    func getTracksBy(genre: Genre?) throws -> [TrackEntity]
    func getSearchTracksBy(query: String, limit: Int) throws -> [TrackEntity]
    func getTrack(id: String) throws -> TrackEntity?
    func insert(tracks: [TrackEntity]) throws
    func delete(track: TrackEntity) throws
    func clearStorage() throws
    func save() throws
}
