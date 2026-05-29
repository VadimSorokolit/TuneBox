//
//  Track.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.05.2026.
//

import Foundation

enum WaveformMapper {
    static func encode(_ waveform: Waveform?) -> Data? {
        guard let waveform else { return nil }
        return try? JSONEncoder().encode(waveform)
    }

    static func decode(_ data: Data?) -> Waveform? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Waveform.self, from: data)
    }
}

enum DownloadState: String, Hashable {
    case idle
    case downloading
    case queued
    case paused
    case completed
    case failed
}

enum FileStorageState: String, Hashable {
    case none
    case exists
    case removed
}

struct Waveform: Codable, Hashable {
    let peaks: [Int]
}

/// Data Transfer Object used for decoding Jamendo API track response

struct TrackDTO: Identifiable, Decodable, Hashable {

    // MARK: - API Properties

    let id: String
    let image: String?
    let trackName: String
    let artistName: String
    let albumName: String
    let releaseDate: String?
    let download: String?
    let waveform: Waveform?

    // MARK: - Custom Properties

    var size: Int?

    init(
        id: String,
        image: String?,
        trackName: String,
        artistName: String,
        albumName: String,
        releaseDate: String?,
        download: String?,
        waveform: Waveform?,
        size: Int? = nil,
    ) {
        self.id = id
        self.image = image
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.releaseDate = releaseDate
        self.download = download
        self.waveform = waveform
        self.size = size
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        trackName = try container.decode(String.self, forKey: .trackName)
        artistName = try container.decode(String.self, forKey: .artistName)
        albumName = try container.decode(String.self, forKey: .albumName)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        download = try container.decodeIfPresent(String.self, forKey: .download)

        if let waveformString = try container.decodeIfPresent(String.self, forKey: .waveform) {
            let data = Data(waveformString.utf8)
            waveform = try? JSONDecoder().decode(Waveform.self, from: data)
        } else {
            waveform = nil
        }
    }

    // MARK: - Computed Properties

    var imageURL: URL? {
        guard let image, !image.isEmpty else {
            return nil
        }

        return URL(string: image)
    }

    var downloadURL: URL? {
        guard let download, !download.isEmpty else {
            return nil
        }

        return URL(string: download)
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case waveform
        case image
        case trackName = "name"
        case artistName = "artist_name"
        case albumName = "album_name"
        case releaseDate = "releasedate"
        case download = "audiodownload"
    }
}
