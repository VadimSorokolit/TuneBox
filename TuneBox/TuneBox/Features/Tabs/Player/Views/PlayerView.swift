//
//  PlayerView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import SwiftUI
import Resolver

struct PlayerView: View {

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            ContentView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadPlaylist()
        }
    }

    // MARK: - Private. Properties

    @Injected private var viewModel: PlayerManaging

    // MARK: - Private. Objects

    private struct HeaderView: View {

        var body: some View {
            Text("Header")
        }
    }

    private struct ContentView: View {
        let viewModel: PlayerManaging

        var body: some View {
            HStack(spacing: 30) {
                Button(action: {
                    viewModel.playPrevious()
                },
                label: {
                    Circle()
                    .fill(Color.gray)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "backward.end.fill")
                    }
                })

                Button(action: {
                    if let playlist = viewModel.playlist {
                        viewModel.handlePlayAction(for: playlist.tracks.first!)
                    }
                },
                    label: {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "play.fill")
                        }
                })

                Button(action: {
                    viewModel.playNext()
                },
                label: {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "forward.end.fill")
                        }
                })
            }
        }
    }
}
