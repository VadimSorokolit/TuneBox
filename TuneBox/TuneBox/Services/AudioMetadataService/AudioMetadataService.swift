//
//  AudioMetadataService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 30.06.2026.
//

import AVFoundation
import SFBAudioEngine

struct TrackMetadata {
    let title: String?
    let artist: String?
    let album: String?
    let date: String?
    let duration: Double?
    let artwork: Data?
}

final class AudioMetadataService: AudioMetadataServicing {

    static func extractMetadata(from url: URL) async throws -> TrackMetadata {
        let file = try AudioFile(readingPropertiesAndMetadataFrom: url)
        let metadata = file.metadata
        let additional = metadata.additionalMetadata

        let title = Self.cleanMetadataValue(
            metadata.title
            ?? Self.additionalValue(for: ["TITLE"], in: additional)
        )

        let artist = Self.cleanMetadataValue(
            metadata.artist?.first
            ?? metadata.albumArtist?.first
            ?? Self.additionalValue(
                for: ["ARTIST", "ALBUMARTIST", "ALBUM ARTIST", "PERFORMER"],
                in: additional
            )
        )

        let album = Self.cleanMetadataValue(
            metadata.albumTitle
            ?? Self.additionalValue(for: ["ALBUM"], in: additional)
        )

        let date = Self.cleanMetadataValue(
            metadata.releaseDate
            ?? Self.additionalValue(
                for: ["DATE", "YEAR", "ORIGINALDATE"],
                in: additional
            )
        )

        return TrackMetadata(
            title: title,
            artist: artist,
            album: album,
            date: date,
            duration: file.properties.duration,
            artwork: metadata.attachedPictures.first?.imageData
        )
    }

    static func artworkDirectory() throws -> URL {
        guard let directory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        return directory
    }

    static func artworkURL(for storedPath: String) -> URL? {
        if storedPath.hasPrefix("/") {
            let url = URL(fileURLWithPath: storedPath)

            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }

            return try? artworkDirectory().appendingPathComponent(url.lastPathComponent)
        }

        return try? artworkDirectory().appendingPathComponent(storedPath)
    }

    func bitrate(for url: URL) async throws -> Int {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)

        guard let track = tracks.first else {
            throw NSError(domain: "NoAudioTrack", code: 0)
        }

        let bitrate = try await track.load(.estimatedDataRate)

        return Int(bitrate / 1000)
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

    private static func cleanMetadataValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let cleaned = value
            .replacingOccurrences(of: "\0", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )

        return cleaned.isEmpty ? nil : cleaned
    }

    private static func additionalValue(
        for keys: [String],
        in dict: [AnyHashable: Any]?
    ) -> String? {
        guard let dict else { return nil }
        let wanted = Set(keys.map { $0.uppercased() })
        for (key, value) in dict {
            guard let keyString = key as? String,
                  wanted.contains(keyString.uppercased())
            else { continue }
            return "\(value)"
        }
        return nil
    }
}
