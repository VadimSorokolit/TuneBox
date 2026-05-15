//
//  TrackEntity.swift
//  TuneBox
//
//  Created by Nintendo on 15.05.2026.
//

import Foundation
import SwiftData

@Model
final class TrackEntity {
    @Attribute(.unique)
    var id: String
    var image: String?
    var trackName: String
    var artistName: String
    var albumName: String
    var releaseDate: String?
    var download: String?
    var size: Int?
    var isDownloaded: Bool
    var downloadingSize: Int

    init(
        id: String,
        image: String?,
        trackName: String,
        artistName: String,
        albumName: String,
        releaseDate: String?,
        download: String?,
        size: Int? = nil,
        isDownloaded: Bool = false,
        downloadingSize: Int = 0
    ) {
        self.id = id
        self.image = image
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.releaseDate = releaseDate
        self.download = download
        self.size = size
        self.isDownloaded = isDownloaded
        self.downloadingSize = downloadingSize
    }
}

extension TrackEntity {

    func update(from track: Track) {
        self.image = track.image
        self.trackName = track.trackName
        self.artistName = track.artistName
        self.albumName = track.albumName
        self.releaseDate = track.releaseDate
        self.download = track.download
        self.size = track.size
        self.isDownloaded = track.isDownloaded
        self.downloadingSize = track.downloadingSize
    }

}
