//
//  ContentView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import SwiftUI
import Resolver

struct ContentView: View {
    @Injected private var viewModel: TransferViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            if let track = viewModel.tracks.first {
                HStack(spacing: 12) {
                    Button("Start") {
                        Task {
                            try? await viewModel.startDownload(track)
                        }
                    }
                    Button("Pause") {
                        Task {
                            await viewModel.pauseDownload(trackID: track.id)
                        }
                    }
                    Button("Resume") {
                        Task {
                            try? await viewModel.resumeDownload(trackID: track.id)
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .modifier(LoadViewModifier())
    }

    struct LoadViewModifier: ViewModifier {
        @Injected var viewModel: TransferViewModel

        func body(content: Content) -> some View {
            content
                .task {
                    viewModel.applyReservedSpace(viewModel.reservedSpace)
                    await viewModel.getPopularTracks(page: 2, perPage: 10)

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
