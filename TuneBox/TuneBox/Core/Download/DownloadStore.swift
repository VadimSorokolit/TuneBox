//
//  DownloadStore.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Foundation

actor DownloadStore {
    private var tasksByTrackID: [String: URLSessionDownloadTask] = [:]
    private var trackIDByTaskIdentifier: [Int: String] = [:]
    private var resumeDataByTrackID: [String: Data] = [:]
    private var stopRequestedTrackIDs: Set<String> = []
    private var relaunchSnapshotTrackIDs: Set<String> = []

    func storeTask(_ task: URLSessionDownloadTask, for trackID: String) {
        if let previous = self.tasksByTrackID[trackID] {
            self.trackIDByTaskIdentifier.removeValue(forKey: previous.taskIdentifier)
        }

        self.tasksByTrackID[trackID] = task
        self.trackIDByTaskIdentifier[task.taskIdentifier] = trackID
    }

    func task(for trackID: String) -> URLSessionDownloadTask? {
        self.tasksByTrackID[trackID]
    }

    func trackID(for task: URLSessionTask) -> String? {
        self.trackIDByTaskIdentifier[task.taskIdentifier]
    }

    func isCurrentTask(_ task: URLSessionTask, for trackID: String) -> Bool {
        guard let stored = self.tasksByTrackID[trackID] else {
            return false
        }

        return stored.taskIdentifier == task.taskIdentifier
    }

    func clearTask(for trackID: String) {
        if let task = self.tasksByTrackID.removeValue(forKey: trackID) {
            self.trackIDByTaskIdentifier.removeValue(forKey: task.taskIdentifier)
        }
    }

    func clearTaskIdentifierMapping(for task: URLSessionTask) {
        self.trackIDByTaskIdentifier.removeValue(forKey: task.taskIdentifier)
    }

    func saveResumeData(_ data: Data?, for trackID: String) {
        if let data {
            self.resumeDataByTrackID[trackID] = data
        }
    }

    func resumeData(for trackID: String) -> Data? {
        self.resumeDataByTrackID[trackID]
    }

    func clearResumeData(for trackID: String) {
        self.resumeDataByTrackID.removeValue(forKey: trackID)
    }

    func stopRequested(for trackID: String) {
        self.stopRequestedTrackIDs.insert(trackID)
    }

    func consumePauseRequested(for trackID: String) -> Bool {
        self.stopRequestedTrackIDs.remove(trackID) != nil
    }

    func relaunchSnapshotRequested(for trackID: String) {
        self.relaunchSnapshotTrackIDs.insert(trackID)
    }

    func consumeRelaunchSnapshotRequested(for trackID: String) -> Bool {
        self.relaunchSnapshotTrackIDs.remove(trackID) != nil
    }

    func activeTrackIDs() -> Set<String> {
        Set(self.tasksByTrackID.keys)
    }
}
