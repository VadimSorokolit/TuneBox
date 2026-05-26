//
//  PersistenceServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation

protocol PersistenceServicing: AnyObject {
    func getTracks() throws -> [TrackEntity]
    func getTrack(id: String) throws -> TrackEntity?
    func insert(tracks: [TrackEntity]) throws
    func upsert(track: TrackEntity) throws
    func delete(track: TrackEntity) throws
    func clearStorage() throws
    func save() throws
}
