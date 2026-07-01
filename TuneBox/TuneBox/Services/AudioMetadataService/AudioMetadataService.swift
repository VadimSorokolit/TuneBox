//
//  AudioMetadataService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 30.06.2026.
//

import AVFoundation

struct TrackMetadata {
    let title: String?
    let artist: String?
    let album: String?
    let duration: Double?
    let artwork: Data?
}

final class AudioMetadataService: AudioMetadataServicing {

    static func extractMetadata(from url: URL) async throws -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        let metadata = try await asset.load(.commonMetadata)
        let duration = try await asset.load(.duration)
        let title = try await metadata.first(where: {$0.commonKey == .commonKeyTitle})?.load(.stringValue)
        let artist = try await metadata.first(where: {$0.commonKey == .commonKeyArtist})?.load(.stringValue)
        let album = try await metadata.first(where: {$0.commonKey == .commonKeyAlbumName})?.load(.stringValue)
        let artwork = try await metadata.first(where: {$0.commonKey == .commonKeyArtwork})?.load(.dataValue)

        return TrackMetadata(
            title: title,
            artist: artist,
            album: album,
            duration: CMTimeGetSeconds(duration),
            artwork: artwork
        )
    }

    static func save(_ data: Data, trackID: String) throws -> URL {
        guard let directory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first
        else {
            throw CocoaError(.fileNoSuchFile)
        }

        let fileURL = directory.appendingPathComponent("\(trackID).jpg")

        try data.write(to: fileURL, options: .atomic)

        return fileURL
    }
}
