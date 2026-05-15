//
//  Track.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.05.2026.
//

import Foundation

struct Track: Identifiable, Decodable, Hashable {

    // MARK: - API Properties

    let id: String
    let image: String?
    let trackName: String
    let artistName: String
    let albumName: String
    let releaseDate: String?
    let download: String?

    // MARK: - Custom Properties

    var size: Int?
    var isDownloaded: Bool = false
    var downloadingSize: Int = 0

    var downloadingProgress: Double {
        guard let size,
                size > 0,
                downloadingSize > 0
        else {
            return 0.0
        }

        return min(1.0, Double(downloadingSize) / Double(size))
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
        self.init(
            id: entity.id,
            image: entity.image,
            trackName: entity.trackName,
            artistName: entity.artistName,
            albumName: entity.albumName,
            releaseDate: entity.releaseDate,
            download: entity.download,
            size: entity.size,
            isDownloaded: entity.isDownloaded,
            downloadingSize: entity.downloadingSize

        )
    }

}
