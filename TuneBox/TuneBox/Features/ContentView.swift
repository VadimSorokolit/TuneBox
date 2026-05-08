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
                                let popularTracks = try await networkService.getPopularTracks(page: 3, perPage: 20)
                                tracks.append(contentsOf: popularTracks)
                                print(tracks.count)
                                if let track = tracks.first {
                                    Task {
                                        do {
                                            let url = try await networkService.downloadTrack(track)
                                            print("✅")
                                            print(url)
                                            do {
                                                let mb = try storageService.getDirectorySizeInMB(from: url)
                                                print(mb)
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
