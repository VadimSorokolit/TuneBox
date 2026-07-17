//
//  PlaylistsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

struct PlaylistsView: View {

    // MARK: - Main Body

    var body: some View {
        if let library = viewModel.library {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(library.playlists) { playlist in
                        NewPlaylistCell(
                            playlist: playlist,
                            onTapGesture: {
                                coordinator.push(.playlist(playlist))
                            }
                        )
                    }
                }
            }
            .contentMargins(.bottom, 26)
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var viewModel: TestManaging
}
