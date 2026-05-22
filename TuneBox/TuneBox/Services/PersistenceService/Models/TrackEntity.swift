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
    var downloadState: String = DownloadState.idle.rawValue
    var downloadingSize: Int = 0
    var fileState: String = FileStorageState.none.rawValue

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
        waveformData: Data?,
        size: Int? = nil,
        downloadState: String = DownloadState.idle.rawValue,
        downloadingSize: Int = 0,
        fileState: String = FileStorageState.none.rawValue,
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
        self.downloadState = downloadState
        self.downloadingSize = downloadingSize
        self.fileState = fileState
    }
}

extension TrackEntity {

    convenience init(track: TrackDTO) {
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
            downloadState: track.downloadState.rawValue,
            downloadingSize: track.downloadingSize,
            fileState: track.fileState.rawValue
        )
    }

    func update(from track: TrackDTO) {
        self.image = track.image
        self.trackName = track.trackName
        self.artistName = track.artistName
        self.albumName = track.albumName
        self.releaseDate = track.releaseDate
        self.download = track.download
        self.waveformData = WaveformMapper.encode(track.waveform)
        self.size = track.size
        self.downloadState = track.downloadState.rawValue
        self.downloadingSize = track.downloadingSize
        self.fileState = track.fileState.rawValue
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
        self.downloadState = entity.downloadState
        self.downloadingSize = entity.downloadingSize
        self.fileState = entity.fileState
    }

}
