//
//  ArtistDetailsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 16.07.2026.
//

import SwiftUI

struct ArtistDetailsView: View {

    // MARK: - Properties. Public

    let artist: MusicLibrary.Artist?

    // MARK: - Main Body

    var body: some View {
        if let artist, artist.albums.isEmpty {
            TracksView(tracks: artist.tracks)
        } else {
            ChipsView(albums: artist?.albums ?? [])
        }
    }

    // MARK: - Private. Objects

    private struct TracksView: View {

        // MARK: - Properties. Public

        let tracks: [TrackEntity]

        // MARK: - Body

        var body: some View {
            Text("Tracks View")
        }
    }

    private struct ChipsView: View {

        // MARK: - Propeties. Public

        let albums: Set<String>

        // MARK: - Body

        var body: some View {
            Text("Chips View")
                .onAppear {
                    print(albums.count)
                }
        }
    }
}
