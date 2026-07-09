//
//  PlayerView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import SwiftUI
import Resolver

struct PlayerView: View {

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            ContentView()
        }
        .onAppear {
            viewModel.loadPlaylist()
        }
    }

    // MARK: - Private. Properties

    @Injected private var viewModel: PlayerManaging

    // MARK: - Private. Objects

    private struct HeaderView: View {

        var body: some View {
            Text("Header")
        }
    }

    private struct ContentView: View {

        var body: some View {
            Text("Player")
        }
    }
}
