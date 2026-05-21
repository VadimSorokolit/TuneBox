//
//  ContentView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import SwiftUI
import Resolver

struct ContentView: View {
    @Injected private var viewModel: TransferManaging

    var body: some View {
        VStack(spacing: 16) {
            if !viewModel.tracks.isEmpty {
                ForEach(viewModel.tracks) { track in
                    BrowsTrackCell(
                        id: track.id,
                        progress: track.downloadingProgress,
                        state: cellState(from: track),
                        onTap: {
                            Task {
                                switch track.downloadState {
                                    case .idle:
                                        await viewModel.startDownload(track)
                                    case .paused:
                                        await viewModel.resumeDownload(trackId: track.id)
                                    case .downloading:
                                        await viewModel.stopDownload(trackId: track.id)
                                    case .completed:
                                        viewModel.deleteDownloadedTrack(id: track.id)
                                    case .queued:
                                        viewModel.cancelQueuedDownload(trackId: track.id)
                                }
                            }
                        }
                    )
                }
            }
        }
        .modifier(LoadViewModifier())
    }

    private func cellState(from track: Track) -> CellState {
        switch track.downloadState {
            case .idle:
                return .idle
            case .downloading:
                return .downloading
            case .queued:
                return .queued
            case .paused:
                return .paused
            case .completed:
                return .completed
        }
    }

    struct LoadViewModifier: ViewModifier {
        @Injected var viewModel: TransferManaging

        func body(content: Content) -> some View {
            content
                .task {
//                    await viewModel.loadFirst()
//                    viewModel.deleteAllTracks()

//                    viewModel.deleteDownloadedTrack(id: "1214935")
//                      viewModel.deleteDownloadedTrack(id: "1214935")
//                    await viewModel .loadNext()
//                    let tracks = viewModel.tracks.filter { $0.downloadState == .paused }
//                    for track in tracks {
//                        await viewModel.startDownload(track)
//                    }
//                    for track in viewModel.tracks {
//                        await viewModel.startDownload(track)
//                        print(track.downloadState)
//                        print(track.downloadingSize)
//                        print(track.fileState)
//                    }
//                    let track = viewModel.getTrack(id: "1214935")
//                    let tracks = viewModel.tracks.filter { $0.isDownloaded == true }
//                    print(tracks.count)
//                    await viewModel.resumeDownload(trackId: "1214935")
//                    print(track?.isRemoved)
//                    if let track = viewModel.tracks.first {
//                        viewModel.deleteDownloadedTrack(id: track.id)
//                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
