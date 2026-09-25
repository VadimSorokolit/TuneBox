//
//  DownloadsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import SwiftUI
import Resolver

enum TracksType: Hashable {
    case active
    case downloaded
    case imported
}

struct DownloadsView: View {

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(transferManagingVM: transferManagingVM)

            SearchBarView(
                searchQuery: $searchQuery,
                isFocused: $isSearchFieldFocused,
                onSubmit: {
                    isSearchFieldFocused = false
                },
                onClear: {
                    transferManagingVM.clearSearchState()
                }
            )

            ContentView(
                rootTabsVM: rootTabsVM,
                transferManagingVM: transferManagingVM,
                playerVM: playerVM
            )
            .dismissKeyboardOnTap(focused: $isSearchFieldFocused)
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top
        )
        .onAppear {
            transferManagingVM.startObservingTracksChanges()
        }
        .onDisappear {
            transferManagingVM.stopObservingTracksChanges()
        }
        .task(id: transferManagingVM.selectedTracksType) {
            await transferManagingVM.fetchTracksSectionBy(transferManagingVM.selectedTracksType)
        }
        .task(id: searchQuery) {
            try? await Task.sleep(for: .milliseconds(300))

            if Task.isCancelled {
                return
            }

            await transferManagingVM.handleSearchQuery(searchQuery)
        }
    }

    // MARK: - Properties. Private

    @Injected private var rootTabsVM: RootTabsManaging
    @Injected private var transferManagingVM: DownloadsPresenting
    @Injected private var playerVM: PlayerManaging
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchQuery: String = ""

    private enum Constants {
        enum Header {
            static let title = "Library"
            static let menuLabelImage = "line.3.horizontal.decrease.circle"
            static let activeButtonImage = "checkmark"
            static let inactiveButtonImage = ""
            static let menuButtonDownloadedTitle = "Downloaded"
            static let menuButtonActiveTitle = "Active Downloads"
        }
    }

    // MARK: - Subviews. Private

    private struct HeaderView: View {

        // MARK: - Properties. Public

        @Environment(\.themeManager) private var theme

        let transferManagingVM: DownloadsPresenting

        // MARK: - Body

        var body: some View {
            TabHeaderView(title: "Library") {
                Menu {
                    Picker(
                        "Library",
                        selection: Binding(
                            get: { transferManagingVM.selectedTracksType },
                            set: { transferManagingVM.setType($0) }
                        )
                    ) {
                        Text("Active Downloads")
                            .tag(TracksType.active)

                        Text("Downloaded")
                            .tag(TracksType.downloaded)
                    }
                } label: {
                    HeaderGlassButton(systemName: "line.3.horizontal.decrease")
                }
                .headerGlassChrome()
            }
        }
    }

    private struct ContentView: View {

        // MARK: - Properties. Public

        let rootTabsVM: RootTabsManaging
        let transferManagingVM: DownloadsPresenting
        let playerVM: PlayerManaging

        // MARK: - Body

        var body: some View {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(transferManagingVM.sections) { section in
                        switch section.type {
                            case .search:
                                searchSectionView(section)

                            case .recents:
                                recentsSectionView(section)

                            case .all:
                                filteredSectionView(section)

                            default:
                                EmptyView()
                        }
                    }
                }
            }
            .padding(.top, 5)
            .bottomContentMargin(
                10,
                0,
                isPlayerVisible: playerVM.isPlayerVisible,
                isPlaying: playerVM.isPlaying,
                isTabBarVisible: rootTabsVM.isTabBarVisible
            )
            .modifier(EmptyTracksStateModifier(showsEmptyState: transferManagingVM.showsEmptyState))
        }

        // MARK: - Private. Methods

        @ViewBuilder
        private func searchSectionView(_ section: TracksSection) -> some View {
            if section.tracks.isNotEmpty,
               transferManagingVM.isSearchMode {
                Section {
                    LazyVStack(spacing: 4) {
                        ForEach(section.tracks, id: \.id) { track in
                            TrackCell(
                                track: track,
                                searchQuery: transferManagingVM.completedSearchQuery,
                                onButtonTap: {
                                    Task {
                                        await transferManagingVM.handleDownloadAction(for: track)
                                    }
                                })
                        }
                    }
                } header: {
                    sectionTracksTitle(section.title)
                }
            }
        }

        @ViewBuilder
        private func recentsSectionView(_ section: TracksSection) -> some View {
            if section.tracks.isNotEmpty,
               transferManagingVM.isSearchMode.isFalse {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 4) {
                            ForEach(section.tracks, id: \.id) { track in
                                GenreCell(
                                    track: track,
                                    onButtonTap: {
                                        Task {
                                            await transferManagingVM.handleDownloadAction(for: track)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                } header: {
                    sectionTracksTitle(section.title)
                }
            }
        }

        @ViewBuilder
        private func filteredSectionView(_ section: TracksSection) -> some View {
            if section.tracks.isNotEmpty,
               transferManagingVM.isSearchMode.isFalse {

                Section(
                    content: {
                        LazyVStack(spacing: 4) {
                            ForEach(section.tracks, id: \.id) { track in
                                TrackCell(
                                    track: track,
                                    onButtonTap: {
                                        Task {
                                            await transferManagingVM.handleDownloadAction(for: track)
                                        }
                                    }
                                )
                            }
                        }
                        .scrollTargetLayout()
                    },
                    header: {
                        sectionTracksTitle(section.title, suffix: transferManagingVM.sectionTitleSuffix)
                    }
                )
            }
        }
    }
}

#Preview {
    DownloadsView()
}
