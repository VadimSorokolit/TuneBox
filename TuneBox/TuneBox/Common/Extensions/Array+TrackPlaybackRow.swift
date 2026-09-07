//
//  Array+TrackPlaybackRow.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.09.2026.
//

import Foundation

struct TrackPlaybackRow {
    let isPlaying: Bool
    let hidesSeparator: Bool
}

extension Array {

    func playbackRow(at index: Int, isCurrent: (Element) -> Bool) -> TrackPlaybackRow {
        let isPlaying = indices.contains(index) && isCurrent(self[index])
        let isBeforeCurrent = index + 1 < count && isCurrent(self[index + 1])

        return TrackPlaybackRow(
            isPlaying: isPlaying,
            hidesSeparator: isPlaying || isBeforeCurrent
        )
    }

}

extension Array where Element == TrackEntity {

    func playbackRow(at index: Int, currentTrack: TrackEntity?) -> TrackPlaybackRow {
        playbackRow(at: index) { $0 === currentTrack }
    }

}

extension Array where Element == SourceFolderItem {

    func playbackRow(
        at index: Int,
        currentTrack: TrackEntity?,
        trackFor: (URL) -> TrackEntity?
    ) -> TrackPlaybackRow {
        playbackRow(at: index) { item in
            guard item.kind == .track,
                  let track = trackFor(item.url) else {
                return false
            }
            return track === currentTrack
        }
    }

}
