//
//  ArtistsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

struct ArtistsView: View {

    // MARK: - Main Body

    var body: some View {
        if let library = viewModel.library {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(library.artists) { artist in
                        ArtistCell(
                            artist: artist,
                            onTapGesture: {
                                coordinator.push(.artist(artist))
                            }
                        )
                    }

                    LibrarySummaryFooter(
                        count: library.artists.count,
                        unitSingular: "artist",
                        unitPlural: "artists",
                        duration: viewModel.tracksDuration(library.artists.flatMap(\.tracks)),
                        size: viewModel.tracksSize(library.artists.flatMap(\.tracks)),
                    )
                }
            }
            .navigationTitle("Artists")
            .padding(.top, 16)
            .contentMargins(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected var viewModel: ImportManaging
}
