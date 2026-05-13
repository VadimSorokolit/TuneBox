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
    private var continuationsByTrackID: [String: CheckedContinuation<URL, Error>] = [:]
    private var pauseRequestedTrackIDs: Set<String> = []

    func storeTask(_ task: URLSessionDownloadTask, for trackID: String) {
        self.tasksByTrackID[trackID] = task
        self.trackIDByTaskIdentifier[task.taskIdentifier] = trackID
    }

    func task(for trackID: String) -> URLSessionDownloadTask? {
        self.tasksByTrackID[trackID]
    }

    func trackID(for task: URLSessionTask) -> String? {
        self.trackIDByTaskIdentifier[task.taskIdentifier]
    }

    func clearTask(for trackID: String) {
        if let task = self.tasksByTrackID.removeValue(forKey: trackID) {
            self.trackIDByTaskIdentifier.removeValue(forKey: task.taskIdentifier)
        }
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

    func setContinuation(_ continuation: CheckedContinuation<URL, Error>, for trackID: String) {
        self.continuationsByTrackID[trackID] = continuation
    }

    func takeContinuation(for trackID: String) -> CheckedContinuation<URL, Error>? {
        self.continuationsByTrackID.removeValue(forKey: trackID)
    }

    func removeContinuation(for trackID: String) {
        self.continuationsByTrackID.removeValue(forKey: trackID)
    }

    func markPauseRequested(for trackID: String) {
        self.pauseRequestedTrackIDs.insert(trackID)
    }

    func consumePauseRequested(for trackID: String) -> Bool {
        self.pauseRequestedTrackIDs.remove(trackID) != nil
    }
}
