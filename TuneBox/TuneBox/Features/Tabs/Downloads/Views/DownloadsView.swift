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
            HeaderView(viewModel: viewModel)

            SearchBarView(
                searchQuery: $searchQuery,
                isFocused: $isSearchFieldFocused,
                onSubmit: {
                    isSearchFieldFocused = false
                },
                onClear: {
                    viewModel.clearSearchState()
                }
            )

            ContentView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top
        )
        .onAppear {
            viewModel.startObservingTracksChanges()
        }
        .onDisappear {
            viewModel.stopObservingTracksChanges()
        }
        .task(id: viewModel.selectedTracksType) {
            await viewModel.fetchTracksSectionBy(viewModel.selectedTracksType)
        }
        .task(id: searchQuery) {
            try? await Task.sleep(for: .milliseconds(300))

            if Task.isCancelled {
                return
            }

            await viewModel.handleSearchQuery(searchQuery)
        }
        .dismissKeyboardOnTap(focused: $isSearchFieldFocused)
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: DownloadsPresenting
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchQuery: String = ""

    // MARK: - Subviews. Private

    private struct HeaderView: View {
        @Environment(\.themeManager) private var theme
        let viewModel: DownloadsPresenting

        private let horizontalPadding: CGFloat = 26

        var body: some View {
            HStack {
                Text("Library")
                    .foregroundStyle(theme.tokens.browseHeaderText)
                    .font(.satoshi.regular.size(34))

                Spacer()

                Menu(
                    content: {
                        Button(action: {
                            viewModel.setType(.active)
                        }, label: {
                            Label(
                                "Active Downloads",
                                systemImage: viewModel.selectedTracksType == .active
                                ? "checkmark"
                                : ""
                            )
                        })

                        Button(action: {
                            viewModel.setType(.downloaded)
                        }, label: {
                            Label(
                                "Downloaded",
                                systemImage: viewModel.selectedTracksType == .downloaded
                                ? "checkmark"
                                : ""
                            )
                        })
                    }, label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 24))
                            .foregroundStyle(theme.tokens.browseHeaderText)
                    }
                )
            }
            .padding(.horizontal, horizontalPadding)
        }
    }

    private struct ContentView: View {
        let viewModel: DownloadsPresenting

        var body: some View {
            ScrollView(
                showsIndicators: false,
                content: {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(viewModel.sections) { section in
                            switch section.type {
                                case .search:
                                    searchSectionView(section)

                                case .recents:
                                    recentsSectionView(section)

                                case .all:
                                    filteredSectionView(section)

                                case .genre, .popular, .imported:
                                    EmptyView()
                            }
                        }
                    }
                }
            )
            .padding(.top, 5)
            .contentMargins(.bottom, 20)
            .modifier(EmptyTracksStateModifier(showsEmptyState: viewModel.showsEmptyState))
        }

        // MARK: - Private. Methods

        @ViewBuilder
        private func searchSectionView(_ section: TracksSection) -> some View {
            if section.tracks.isNotEmpty,
               viewModel.isSearchMode {

                Section(
                    content: {
                        LazyVStack(spacing: 4) {
                            ForEach(section.tracks, id: \.id) { track in
                                TrackCell(
                                    track: track,
                                    searchQuery: viewModel.completedSearchQuery,
                                    onButtonTap: {
                                        Task {
                                            await viewModel.handleDownloadAction(for: track)
                                        }
                                    })
                            }
                        }
                    },
                    header: {
                        sectionTracksTitle(section.title)
                    }
                )
            }
        }

        @ViewBuilder
        private func recentsSectionView(_ section: TracksSection) -> some View {
            if section.tracks.isNotEmpty,
               viewModel.isSearchMode.isFalse {

                Section(
                    content: {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 4) {
                                ForEach(section.tracks, id: \.id) { track in
                                    GenreCell(
                                        track: track,
                                        onButtonTap: {
                                            Task {
                                                await viewModel.handleDownloadAction(for: track)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }, header: {
                        sectionTracksTitle(section.title)
                    }
                )
            }
        }

        @ViewBuilder
        private func filteredSectionView(_ section: TracksSection) -> some View {
            if section.tracks.isNotEmpty,
               viewModel.isSearchMode.isFalse {

                Section(
                    content: {
                        LazyVStack(spacing: 4) {
                            ForEach(section.tracks, id: \.id) { track in
                                TrackCell(
                                    track: track,
                                    onButtonTap: {
                                        Task {
                                            await viewModel.handleDownloadAction(for: track)
                                        }
                                    }
                                )
                            }
                        }
                    },
                    header: {
                        sectionTracksTitle(section.title, suffix: viewModel.sectionTitleSuffix)
                    }
                )
            }
        }
    }
}

#Preview {
    DownloadsView()
}
