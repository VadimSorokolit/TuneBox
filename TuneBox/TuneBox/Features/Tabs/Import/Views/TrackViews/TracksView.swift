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
                    Image(systemName: LibraryItem.tracks.systemImage)
                } description: {
                    Text("\(LibraryItem.tracks.rawValue.capitalized) you add to your library will appear here.")
                }
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(importManagingVM.sectionedTracks(from: tracks)) { section in
                            Section {
                                sectionTracksTitle(
                                    section.letter,
                                    font: .system(size: 15, weight: .medium),
                                    foregroundStyle: .gray,
                                    topPadding: 20,
                                    bottomPadding: 8,
                                    horizontalPadding: GlobalConstants.Cell.defaultPadding,
                                    hasSeparator: false
                                )
                                .listRowInsets(EdgeInsets())

                                ForEach(Array(section.tracks.enumerated()), id: \.element.id) { index, track in
                                    let row = section.tracks.playbackRow(at: index, currentTrack: playerVM.track)

                                    TrackCoverCell(
                                        track: track,
                                        isPlaying: row.isPlaying,
                                        hidesSeparator: row.hidesSeparator,
                                        onTapGesture: {
                                            playerVM.handlePlayAction(
                                                for: track,
                                                in: playbackQueue,
                                                navigationPath: coordinator.path
                                            )
                                        }
                                    )
                                    .id(track.id)
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
                                duration: importManagingVM.tracksDuration(tracks),
                                size: importManagingVM.tracksSize(tracks)
                            )
                            .frame(maxWidth: .infinity)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                        .listSectionSeparator(.hidden)

                        Section {
                            Color.clear
                                .frame(
                                    height: BottomLayout.inset(
                                        isPlayerVisible: playerVM.isPlayerVisible,
                                        isPlaying: playerVM.isPlaying,
                                        isTabBarVisible: rootTabsVM.isTabBarVisible,
                                        screenHeight: screenHeight
                                    )
                                )
                                .animation(.easeInOut(duration: 0.35), value: playerVM.isPlaying)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .listSectionSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 1)
                    .task(id: navigationTitle) {
                        await Task.yield()
                        scrollToPlayingTrack(proxy: proxy)
                    }
                    .onChange(of: playerVM.scrollToCurrentTrackRequest) { _, _ in
                        scrollToPlayingTrack(proxy: proxy)
                    }
                }
            }
        }
        .customNavigationTitle(navigationTitle)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            Task {
                importManagingVM.startObservingTracksChanges()
            }
        }
        .onDisappear {
            importManagingVM.stopObservingTracksChanges()
        }
    }

    // MARK: - Properties. Private

    @Environment(\.screenHeight) private var screenHeight
    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var rootTabsVM: RootTabsManaging
    @Injected private var importManagingVM: ImportManaging
    @Injected private var playerVM: PlayerManaging

    private var tracks: [TrackEntity] {
        switch content {
            case .library:
                importManagingVM.libraryTracks()

            case .downloads:
                importManagingVM.libraryTracks(onlyAPI: true)

            case .fixed(let tracks):
                tracks
        }
    }

    private var playbackQueue: [TrackEntity] {
        importManagingVM.sortedTracksAlphabetically(tracks)
    }

    private func scrollToPlayingTrack(proxy: ScrollViewProxy) {
        guard let trackID = playerVM.track?.id,
              tracks.contains(where: { $0.id == trackID }) else {
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(trackID, anchor: .center)
        }
    }
}
