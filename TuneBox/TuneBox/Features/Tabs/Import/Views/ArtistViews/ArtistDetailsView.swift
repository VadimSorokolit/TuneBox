//
//  ArtistDetailsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 16.07.2026.
//

import SwiftUI

enum LibrarySegment: Int, CaseIterable, SegmentedItem {
    case albums
    case tracks

    var title: String {
        switch self {
            case .albums:
                "Albums"
            case .tracks:
                "Tracks"
        }
    }
}

struct ArtistDetailsView: View {

    // MARK: - Properties. Public

    let artist: MusicLibrary.Artist?

    // MARK: - Main Body

    var body: some View {
        if let artist {
            if artist.albums.isEmpty {
                TracksView(tracks: artist.tracks)
            } else {
                ChipsView(artist: artist)
            }
        } else {
            EmptyView()
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

        let artist: MusicLibrary.Artist

        // MARK: - Body

        var body: some View {
            VStack(spacing: 20) {
                SegmentedControl(
                    selected: $selected,
                    direction: $direction,
                    items: LibrarySegment.allCases
                )

                ZStack {
                    switch selected {
                        case .albums:
                            Text("Album content")
                                .id(selected)
                                .segmentTransition(direction)

                        case .tracks:
                            Text("Tracks content")
                                .id(selected)
                                .segmentTransition(direction)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: selected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 26)
            .padding(.horizontal, 26)
        }

        // MARK: - Properties. Private

        @State private var selected: LibrarySegment = .albums
        @State private var direction: SlideDirection = .forward
    }
}
