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

struct Track: Identifiable, Decodable, Hashable {

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
    var downloadState: DownloadState = .idle
    var downloadingSize: Int = 0
    var fileState: FileStorageState = .none

    var downloadingProgress: Double {
        guard let size,
                size > 0,
                downloadingSize > 0
        else {
            return 0.0
        }

        return min(1.0, Double(downloadingSize) / Double(size))
    }

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
        trackDownloadState: DownloadState = .idle,
        downloadingSize: Int = 0,
        fileState: FileStorageState = .none
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
        self.downloadState = trackDownloadState
        self.downloadingSize = downloadingSize
        self.fileState = fileState
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

extension Track {

    init(entity: TrackEntity) {
        self.id = entity.id
        self.image = entity.image
        self.trackName = entity.trackName
        self.artistName = entity.artistName
        self.albumName = entity.albumName
        self.releaseDate = entity.releaseDate
        self.download = entity.download
        self.waveform = WaveformMapper.decode(entity.waveformData)
        self.size = entity.size
        self.downloadState = DownloadState(rawValue: entity.downloadState) ?? .idle
        self.downloadingSize = entity.downloadingSize
        self.fileState = FileStorageState(rawValue: entity.fileState) ?? .none
    }

}
