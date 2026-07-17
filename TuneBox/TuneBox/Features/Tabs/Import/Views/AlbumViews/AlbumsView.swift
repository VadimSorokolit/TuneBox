//
//  AlbumsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

struct AlbumsView: View {

    // MARK: - Main Body

    var body: some View {
        if let library = viewModel.library {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(library.albums) { album in
                        AlbumCell(
                            album: album,
                            onTapGesture: {
                                coordinator.push(.album(album))
                            }
                        )
                    }

                    Text(
                        "\(library.albums.count) "
                        + "\(library.albums.count == 1 ? "album" : "albums") · "
                        + "\(viewModel.tracksDuration(library.albums.flatMap(\.tracks)).formattedDuration) · "
                        + "\(viewModel.tracksSize(library.albums.flatMap(\.tracks)).formattedFileSize)"
                    )
                    .padding(.top, 20)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.gray)
                }
            }
            .navigationTitle("Albums")
            .padding(.top, 16)
            .contentMargins(.bottom, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: TestManaging
    @Environment(AppCoordinator.self) private var coordinator
}
