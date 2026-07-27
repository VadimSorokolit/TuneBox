//
//  TracksView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

enum TracksContent: Hashable {
    case library
    case downloads
    case fixed([TrackEntity])
}

struct TracksView: View {

    // MARK: - Properties. Public

    var navigationTitle: String
    var content: TracksContent

    // MARK: - Main Body

    var body: some View {
        Group {
            if tracks.isEmpty {
                ContentUnavailableView {
                    Image(systemName: "music.note.list")
                } description: {
                    Text("Tracks you add to your library will appear here.")
                }
            } else {
                List {
                    ForEach(viewModel.sectionedTracks(from: tracks)) { section in
                        Section {
                            sectionTracksTitle(
                                section.letter,
                                font: .system(size: 16, weight: .regular),
                                foregroundStyle: .gray,
                                topPadding: 10,
                                bottomPadding: 0,
                                horizontalPadding: 26,
                                hasSeparator: true
                            )
                            .listRowInsets(EdgeInsets())

                            ForEach(section.tracks) { track in
                                TrackArtworkCell(
                                    track: track,
                                    isPlaying: false,
                                    onTapGesture: {}
                                )
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .sectionIndexLabel(section.letter)
                        .listSectionSeparator(.hidden)
                    }

                    Section {
                        LibrarySummaryFooter(
                            count: tracks.count,
                            unitSingular: "track",
                            unitPlural: "tracks",
                            duration: viewModel.tracksDuration(tracks),
                            size: viewModel.tracksSize(tracks),
                            topPadding: 10
                        )
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    .listSectionSeparator(.hidden)
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 1)
                .contentMargins(.bottom, 20)
            }
        }
        .navigationTitle(navigationTitle)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            Task {
                viewModel.startObservingTracksChanges()
            }
        }
        .onDisappear {
            viewModel.stopObservingTracksChanges()
        }
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: ImportManaging

    private var tracks: [TrackEntity] {
        switch content {
            case .library:
                viewModel.libraryTracks()

            case .downloads:
                viewModel.libraryTracks(onlyAPI: true)

            case .fixed(let tracks):
                tracks
        }
    }
}
