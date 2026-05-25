//
//  ContentView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import SwiftUI
import Resolver

struct ContentView: View {
    @Injected private var transferViewModel: TransferManaging
    @Injected private var playerViewModel: PlayerManaging

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    Task {
                        await transferViewModel.loadFirst()
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
                .disabled(transferViewModel.tracks.isEmpty == false)

                Spacer()

                Button(action: {
                    Task {
                        await transferViewModel.loadNext()
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
                    transferViewModel.resetTransferState()
                }, label: {
                    Circle().fill(Color.red)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "trash")
                                .frame(width: 30, height: 30)
                                .foregroundStyle(Color.white)
                        )
                })
                .disabled(transferViewModel.tracks.isEmpty)
            }
            .padding(.horizontal)

            VStack(spacing: 5) {
                if !transferViewModel.tracks.isEmpty {
                    ForEach(transferViewModel.tracks, id: \.persistentModelID) { track in
                        BrowsTrackCell(
                            id: track.id,
                            progress: track.downloadingProgress,
                            state: cellState(from: track),
                            onTap: {
                                Task {
                                    await transferViewModel.handleDownloadAction(for: track)
                                }
                            },
                            onPlayTap: {
                                playerViewModel.handlePlayAction(for: track)
                            },
                            isPlaying: playerViewModel.isPlaying(track)
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
        .task {
            await transferViewModel.loadFirst()
        }
    }

    private func cellState(from track: TrackEntity) -> CellState {
        switch track.downloadState {
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

}

#Preview {
    ContentView()
}
