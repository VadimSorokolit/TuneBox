//
//  TracksView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

struct TracksView: View {

    // MARK: - Properties. Public

    var onlyAPI: Bool = false

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
                    ForEach(sectionedTracks) { section in
                        Section {
                            sectionTracksTitle(
                                section.letter,
                                font: .system(size: 16, weight: .regular),
                                foregroundStyle: .gray,
                                verticalPadding: 0,
                                horizontalPadding: 0
                            )

                            ForEach(section.tracks) { item in
                                NewTrackCell(
                                    index: item.index,
                                    track: item.track,
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
                .contentMargins(.bottom, 16)
            }
        }
        .navigationTitle("Tracks")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            Task {
                viewModel.startObservingTracksChanges()
                await viewModel.refreshLibrary()
            }
        }
        .onDisappear {
            viewModel.stopObservingTracksChanges()
        }
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: ImportManaging

    private var tracks: [TrackEntity] {
        let all = viewModel.library?.tracks ?? []
        let filtered = onlyAPI
            ? all.filter { $0.source == .api }
            : all

        var seen = Set<DeduplicationKey>()

        return filtered.filter { track in
            seen.insert(
                DeduplicationKey(
                    songName: track.songName,
                    artistName: track.artistName
                )
            ).inserted
        }
    }

    private var sectionedTracks: [TrackAlphabetSection] {
        let grouped = Dictionary(grouping: tracks) { track -> String in
            let trimmed = track.songName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let first = trimmed.first else { return "#" }

            let letter = String(first).uppercased()
            return letter.rangeOfCharacter(from: .letters) != nil ? letter : "#"
        }

        let sortedLetters = grouped.keys.sorted { lhs, rhs in
            if lhs == "#" { return false }
            if rhs == "#" { return true }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        var nextIndex = 1

        return sortedLetters.map { letter in
            let sectionTracks = (grouped[letter] ?? []).map { track in
                let item = IndexedTrack(index: nextIndex, track: track)
                nextIndex += 1
                return item
            }

            return TrackAlphabetSection(letter: letter, tracks: sectionTracks)
        }
    }

    // MARK: - Private. Objects

    private struct DeduplicationKey: Hashable {
        let songName: String
        let artistName: String
    }

    private struct TrackAlphabetSection: Identifiable {
        let letter: String
        let tracks: [IndexedTrack]

        var id: String { letter }
    }

    private struct IndexedTrack: Identifiable {
        let index: Int
        let track: TrackEntity

        var id: String { track.id }
    }
}
