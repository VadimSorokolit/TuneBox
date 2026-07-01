//
//  AudioMetadataServicing.swift
//  TuneBox
//
//  Created Vadim Sorokolit on 30.06.2026.
//

import Foundation

protocol AudioMetadataServicing {
    static func extractMetadata(from url: URL) async throws -> TrackMetadata
    static func save(_ data: Data, trackID: String) throws -> URL
}
