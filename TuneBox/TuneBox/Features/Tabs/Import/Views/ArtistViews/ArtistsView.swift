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

                    Text(
                        "\(library.artists.count) "
                        + "\(library.artists.count == 1 ? "artist" : "artists") · "
                        + "\(viewModel.tracksDuration(library.artists.flatMap(\.tracks)).formattedDuration) · "
                        + "\(viewModel.tracksSize(library.artists.flatMap(\.tracks)).formattedFileSize)"
                    )
                    .padding(.top, 20)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.gray)
                }
            }
            .navigationTitle("Artists")
            .padding(.top, 16)
            .contentMargins(.bottom, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected var viewModel: ImportManaging
}
