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
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

                HStack(spacing: 12) {
                    Button("Start") {
                        Task {
                            await viewModel.startDownload(viewModel.tracks.first!)
                        }
                    }

                    Button("Pause") {
                        Task {
                            await viewModel.stopDownload(trackId: viewModel.tracks.first!.id)
                        }
                    }

                    Button("Resume") {
                        Task {
                            await viewModel.resumeDownload(
                                trackId: viewModel.tracks.first!.id
                            )
                        }
                    }
                }
                .buttonStyle(.bordered)
        }
        .padding()
        .modifier(LoadViewModifier())
    }

    struct LoadViewModifier: ViewModifier {
        @Injected var viewModel: TransferManaging

        func body(content: Content) -> some View {
            content
                .task {

//                    viewModel.deleteDownloadedTrack(id: "1214935")
//                      viewModel.deleteDownloadedTrack(id: "1214935")
//                    await viewModel .loadNext()
//                    await viewModel.loadFirst()
//                    for track in viewModel.tracks {
//                        await viewModel.startDownload(track)
//                    }
//                    let track = viewModel.getTrack(id: "1214935")
//                    let tracks = viewModel.tracks.filter { $0.isDownloaded == true }
//                    print(tracks.count)
//                    await viewModel.resumeDownload(trackId: "1214935")
//                    viewModel.deleteAllTracks()
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
