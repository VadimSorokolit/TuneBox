//
//  ContentView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import SwiftUI
import Resolver

struct ContentView: View {

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
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
                    await viewModel.getPopularTracks(page: 1, perPage: 10)
                    
                    if let track = viewModel.tracks.first {
                        viewModel.deleteDownloadedTrack(id: track.id)
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
