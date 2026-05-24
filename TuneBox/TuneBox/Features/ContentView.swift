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
    @State private var playingTrackId: String?
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    Task {
                        await viewModel.loadFirst()
                    }
                }, label: {
                    Circle().fill(Color.yellow)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note")
                                .frame(width: 30, height: 30)
                                .foregroundStyle(Color.white)
                        )
                })
                .disabled(viewModel.tracks.isEmpty == false)

                Spacer()

                Button(action: {
                    Task {
                        await viewModel.loadNext()
                    }
                }, label: {
                    Circle().fill(Color.blue)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .frame(width: 30, height: 30)
                                .foregroundStyle(Color.white)
                        )
                })

                Spacer()

                Button(action: {
                    viewModel.resetTransferState()
                }, label: {
                    Circle().fill(Color.red)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "trash")
                                .frame(width: 30, height: 30)
                                .foregroundStyle(Color.white)
                        )
                })
                .disabled(viewModel.tracks.isEmpty)
            }
            .padding(.horizontal)

            VStack(spacing: 5) {
                if !viewModel.tracks.isEmpty {
                    ForEach(viewModel.tracks, id: \.id) { track in
                        BrowsTrackCell(
                            id: track.id,
                            progress: track.downloadingProgress,
                            state: cellState(from: track),
                            onTap: {
                                Task {
                                    switch DownloadState(rawValue: track.downloadState) ?? .idle {
                                        case .idle:
                                            await viewModel.startDownload(track)
                                        case .paused:
                                            await viewModel.resumeDownload(track: track)
                                        case .downloading:
                                            await viewModel.stopDownload(track: track)
                                        case .completed:
                                            viewModel.deleteDownloadedTrack(track: track)
                                        case .queued:
                                            viewModel.cancelQueuedDownload(track: track)
                                        case .failed:
                                            viewModel.errorMessage = nil
                                            await viewModel.startDownload(track)
                                    }
                                }
                            },
                            onPlayTap: {
                                if playingTrackId == track.id && isPlaying {
                                    AudioService.shared.pause()
                                    isPlaying = false
                                } else {
                                    AudioService.shared.play(trackId: track.id)
                                    playingTrackId = track.id
                                    isPlaying = AudioService.shared.isPlaying
                                }

                            },
                            isPlaying: playingTrackId == track.id
                            && isPlaying
                        )
                        .padding(.horizontal)
                    }
                } else {
                    EmptyView()
                }
            }
        }
        .modifier(LoadViewModifier())
    }

    private func cellState(from track: TrackEntity) -> CellState {
        switch DownloadState(rawValue: track.downloadState) ?? .idle {
            case .idle:
                return .idle
            case .paused:
                return .paused
            case .downloading:
                return .downloading
            case .completed:
                return .completed
            case .queued:
                return .queued
            case .failed:
                return .failed
        }
    }

    struct LoadViewModifier: ViewModifier {
        @Injected var viewModel: TransferManaging

        func body(content: Content) -> some View {
            content
                .task {
                    await viewModel.loadFirst()
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
