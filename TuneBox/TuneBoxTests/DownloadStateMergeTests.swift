//
//  DownloadStateMergeTests.swift
//  TuneBoxTests
//
//  Created by Cursor on 01.06.2026.
//

import Testing
@testable import TuneBox

struct DownloadStateMergeTests {

    @Test(arguments: [
        (DownloadState.completed, DownloadState.idle, DownloadState.completed),
        (DownloadState.idle, DownloadState.completed, DownloadState.completed),
        (DownloadState.downloading, DownloadState.queued, DownloadState.downloading),
        (DownloadState.failed, DownloadState.idle, DownloadState.failed),
        (DownloadState.paused, DownloadState.downloading, DownloadState.downloading)
    ])
    func downloadStateMergePicksHigherPriority(
        lhs: DownloadState,
        rhs: DownloadState,
        expected: DownloadState
    ) {
        #expect(lhs.merged(with: rhs) == expected)
        #expect(rhs.merged(with: lhs) == expected)
    }

    @Test(arguments: [
        (FileStorageState.removed, FileStorageState.exists, FileStorageState.removed),
        (FileStorageState.exists, FileStorageState.none, FileStorageState.exists),
        (FileStorageState.none, FileStorageState.removed, FileStorageState.removed)
    ])
    func fileStorageStateMergePicksHigherPriority(
        lhs: FileStorageState,
        rhs: FileStorageState,
        expected: FileStorageState
    ) {
        #expect(lhs.merged(with: rhs) == expected)
        #expect(rhs.merged(with: lhs) == expected)
    }

    @Test
    func mergeTransferStatePreservesCompletedOverIdle() {
        let stored = TrackEntity(
            id: "1",
            image: nil,
            trackName: "A",
            artistName: "B",
            albumName: "C",
            releaseDate: nil,
            download: nil,
            waveformData: nil,
            size: 1_000,
            downloadingSize: 1_000,
            downloadStateRawValue: DownloadState.completed.rawValue,
            fileStateRawValue: FileStorageState.exists.rawValue
        )

        let incoming = TrackEntity(
            id: "1",
            image: nil,
            trackName: "A",
            artistName: "B",
            albumName: "C",
            releaseDate: nil,
            download: nil,
            waveformData: nil,
            size: 1_000
        )

        stored.mergeTransferState(from: incoming)

        #expect(stored.downloadState == .completed)
        #expect(stored.downloadingSize == 1_000)
        #expect(stored.fileState == .exists)
    }
}
