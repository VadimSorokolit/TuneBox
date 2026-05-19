//
//  TrackEntity.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.05.2026.
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
    var waveformData: Data?
    var size: Int?
    var isDownloaded: Bool
    var isRemoved: Bool = false
    var downloadingSize: Int

    init(
        id: String,
        image: String?,
        trackName: String,
        artistName: String,
        albumName: String,
        releaseDate: String?,
        download: String?,
        waveformData: Data?,
        size: Int? = nil,
        isDownloaded: Bool = false,
        isRemoved: Bool = false,
        downloadingSize: Int = 0
    ) {
        self.id = id
        self.image = image
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.releaseDate = releaseDate
        self.download = download
        self.waveformData = waveformData
        self.size = size
        self.isDownloaded = isDownloaded
        self.isRemoved = isRemoved
        self.downloadingSize = downloadingSize
    }
}

extension TrackEntity {

    convenience init(track: Track) {
        self.init(
            id: track.id,
            image: track.image,
            trackName: track.trackName,
            artistName: track.artistName,
            albumName: track.albumName,
            releaseDate: track.releaseDate,
            download: track.download,
            waveformData: WaveformMapper.encode(track.waveform),
            size: track.size,
            isDownloaded: track.isDownloaded,
            isRemoved: track.isRemoved,
            downloadingSize: track.downloadingSize
        )
    }

    func update(from track: Track) {
        self.image = track.image
        self.trackName = track.trackName
        self.artistName = track.artistName
        self.albumName = track.albumName
        self.releaseDate = track.releaseDate
        self.download = track.download
        self.waveformData = WaveformMapper.encode(track.waveform)
        self.size = track.size
        self.isDownloaded = track.isDownloaded
        self.isDownloaded = track.isRemoved
        self.downloadingSize = track.downloadingSize
    }

    func update(from entity: TrackEntity) {
        self.image = entity.image
        self.trackName = entity.trackName
        self.artistName = entity.artistName
        self.albumName = entity.albumName
        self.releaseDate = entity.releaseDate
        self.download = entity.download
        self.waveformData = entity.waveformData
        self.size = entity.size
        self.isDownloaded = entity.isDownloaded
        self.isRemoved = entity.isRemoved
        self.downloadingSize = entity.downloadingSize
    }

}
