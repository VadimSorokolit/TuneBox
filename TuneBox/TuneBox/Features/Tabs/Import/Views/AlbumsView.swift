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
        if let libray = viewModel.library {
            ScrollView(showsIndicators: false) {
                ForEach(libray.albums) { album in
                    LazyVStack(spacing: 0) {
                        AlbumCell(
                            album: album,
                            onTapGesture: {
                                coordinator.push(.album(album: album))
                            }
                        )
                    }
                }
            }
            .navigationTitle("Albums")
            .padding(.top, 16)
            .contentMargins(.bottom, 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: TestManaging
    @Environment(AppCoordinator.self) private var coordinator
}
