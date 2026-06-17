//
//  TrackEntity.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.05.2026.
//

import Foundation
import SwiftData

enum TrackSource: String {
    case api
    case imported
}

@Model
final class TrackEntity {
    @Attribute(.unique)
    var id: String

    var image: String?
    var songName: String
    var artistName: String
    var albumName: String
    var releaseDate: String?
    var download: String?
    var waveformData: Data?
    var size: Int?
    var isPopular: Bool?
    var downloadingSize: Int = 0
    var lastStateChangeAt: Date?
    var downloadQueueIndex: Int?
    var genreRawValue: String?
    private var duration: Int?
    private var sourceRawValue: String = TrackSource.api.rawValue
    private(set) var downloadStateRawValue: String = DownloadState.idle.rawValue
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

    var source: TrackSource {
        get { TrackSource(rawValue: sourceRawValue) ?? .api }
        set { sourceRawValue = newValue.rawValue }
    }

    var formattedDuration: String {
        guard let duration else {
            return "--:--"
        }

        let minutes = duration / 60
        let seconds = duration % 60

        return String(format: "%d:%02d", minutes, seconds)
    }

    var genre: Genre? {
        get {
            guard let genreRawValue else {
                return nil
            }
            return Genre(rawValue: genreRawValue)
        }

        set {
            self.genreRawValue = newValue?.rawValue
        }
    }

    var imageURL: URL? {
        guard let image, !image.isEmpty else {
            return nil
        }

        let normalizedImageURLString = image.replacingOccurrences(of: "\\/", with: "/")

        return URL(string: normalizedImageURLString)
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
        songName: String,
        duration: Int?,
        artistName: String,
        albumName: String,
        releaseDate: String?,
        download: String?,
        waveformData: Data?,
        size: Int?,
        isPopular: Bool? = nil,
        downloadingSize: Int = 0,
        genreRawValue: String? = nil,
        sourceRawValue: String = TrackSource.api.rawValue,
        downloadStateRawValue: String = DownloadState.idle.rawValue,
        fileStateRawValue: String = FileStorageState.none.rawValue,
        downloadQueueIndex: Int? = nil
    ) {
        self.id = id
        self.image = image
        self.songName = songName
        self.duration = duration
        self.artistName = artistName
        self.albumName = albumName
        self.releaseDate = releaseDate
        self.download = download
        self.waveformData = waveformData
        self.size = size
        self.isPopular = isPopular
        self.downloadingSize = downloadingSize
        self.genreRawValue = genreRawValue
        self.sourceRawValue = sourceRawValue
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
            songName: track.songName,
            duration: track.duration,
            artistName: track.artistName,
            albumName: track.albumName,
            releaseDate: track.releaseDate,
            download: track.download,
            waveformData: WaveformMapper.encode(track.waveform),
            size: track.size
        )
    }

    /// Merges API/catalog fields without touching transfer state
    func updateMetadata(from entity: TrackEntity) {
        self.image = entity.image
        self.songName = entity.songName
        self.duration = entity.duration
        self.artistName = entity.artistName
        self.albumName = entity.albumName
        self.releaseDate = entity.releaseDate
        self.download = entity.download
        self.waveformData = entity.waveformData
        self.size = entity.size

        if let isPopular = entity.isPopular {
            self.isPopular = isPopular
        }

        if entity.genreRawValue != nil {
            self.genre = entity.genre
        }
    }

    /// Keeps the more advanced transfer snapshot (e.g. `.completed` over `.idle`)
    func mergeTransferState(from entity: TrackEntity) {
        let previousState = self.downloadState
        let mergedState = previousState.merged(with: entity.downloadState)

        self.downloadState = mergedState
        self.downloadingSize = max(self.downloadingSize, entity.downloadingSize)
        self.fileState = self.fileState.merged(with: entity.fileState)

        if mergedState == .queued {
            let indices = [self.downloadQueueIndex, entity.downloadQueueIndex].compactMap { $0 }

            self.downloadQueueIndex = indices.min()
        } else if mergedState != .queued {
            self.downloadQueueIndex = nil
        }
    }

}
