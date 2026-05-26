//
//  DownloadManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation

protocol DownloadManaging: AnyObject {
    func startDownload(_ track: TrackEntity) async
    func stopDownload(track: TrackEntity) async
    func resumeDownload(track: TrackEntity) async
    func cancelQueuedDownload(track: TrackEntity)
    func deleteDownloadedTrack(track: TrackEntity)
}
