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
    var downloadingSize: Int = 0
    var downloadQueueIndex: Int?
    private var downloadStateRawValue: String = DownloadState.idle.rawValue
    private var fileStateRawValue: String = FileStorageState.none.rawValue

    // MARK: - Computed Properties

    var downloadState: DownloadState {
        get {
            DownloadState(rawValue: self.downloadStateRawValue) ?? .idle
        }

        set {
            self.downloadStateRawValue = newValue.rawValue
        }
    }

    var fileState: FileStorageState {
        get {
            FileStorageState(rawValue: self.fileStateRawValue) ?? .none
        }

        set {
            self.fileStateRawValue = newValue.rawValue
        }
    }

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
        downloadingSize: Int = 0,
        downloadStateRawValue: String = DownloadState.idle.rawValue,
        fileStateRawValue: String = FileStorageState.none.rawValue,
        downloadQueueIndex: Int? = nil
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
        self.downloadingSize = downloadingSize
        self.downloadStateRawValue = downloadStateRawValue
        self.fileStateRawValue = fileStateRawValue
        self.downloadQueueIndex = downloadQueueIndex
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
            size: track.size
        )
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
        self.downloadingSize = entity.downloadingSize
        self.downloadState = entity.downloadState
        self.fileState = entity.fileState
        self.downloadQueueIndex = entity.downloadQueueIndex
    }

}
