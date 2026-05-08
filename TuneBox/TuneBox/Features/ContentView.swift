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
        @Injected var networkService: NetworkServicing
        @Injected var storageService: StorageServicing
        @State private var tracks: [Track] = []

        func body(content: Content) -> some View {
            content
                .onAppear {
//                    Task {
//                        do {
//                            let size = try await networkService.getTrackSize(id: 623192)
//                            print(size)
//                        } catch {
//                            print(APIError.from(error).localizedDescription)
//                        }
//                    }
                    do {
                        try storageService.checkEnoughFreeStorage(requiredGB: 330)

                        Task {
                            do {
                                let popularTracks = try await networkService.getPopularTracks(page: 10, perPage: 20)
                                tracks.append(contentsOf: popularTracks)
                                print(tracks.count)
                                if let track = tracks.first {
                                    Task {
                                        do {
                                            try await networkService.startDownload(track)
                                            print("✅")

                                            do {
//                                                try storageService.deleteDownloadedTrack(id: track.id)
//                                                print(tracks.count)
//                                                try storageService.deleteAllTracks()
//                                                print(tracks.count)
                                                let size = try await storageService.getDirectorySizeInMB()
                                                print(size)
                                            } catch {
                                                print("Error")
                                            }
                                        } catch {
                                            print(APIError.from(error).localizedDescription)
                                        }
                                    }
                                }
                            } catch {
                                print(APIError.from(error).localizedDescription)
                            }
                        }
                    } catch {
                        print("❌")
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
