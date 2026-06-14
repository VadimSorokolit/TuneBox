//
//  BrowsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Resolver
import SwiftUI

struct BrowseView: View {
    @Injected var viewModel: TransferManaging
    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedGenre: Genre = .all
    @State private var slideDirection: SlideDirection = .forward
    @State private var searchQuery: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            SearchBarView(
                searchQuery: $searchQuery,
                isFocused: $isTextFieldFocused,
                onSubmit: {
                    isTextFieldFocused = false
                },
                onClear: {
                    viewModel.clearSearchState()
                })
            .task(id: searchQuery) {
                try? await Task.sleep(for: .milliseconds(300))

                if Task.isCancelled {
                    return
                }

                if viewModel.completedSearchQuery != searchQuery {
                    viewModel.loadSearchBy(query: searchQuery)
                }
            }

            ContentView(selectedGenre: $selectedGenre,
                        slideDirection: $slideDirection,
                        searchQuery: $searchQuery
            )
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top
        )
        .task {
            guard viewModel.sections.flatMap( \.tracks).isEmpty else {
                return
            }

            await viewModel.loadFirstPopular()
            await viewModel.loadFirstBy(genre: nil)
        }
        .overlay {
            if viewModel.shouldShowCentralSpinner {
                SpinnerView()
            }
        }
        .onChange(of: searchQuery) { _, query in
            if query.isEmpty {
                viewModel.clearSearchState()
            }
        }
        .onChange(of: viewModel.selectedTab) { _, _ in
            isTextFieldFocused = false
        }
        .onTapGesture {
            isTextFieldFocused = false
        }
    }

    private struct HeaderView: View {
        @Injected var viewModel: TransferManaging
        @Environment(\.themeManager) private var theme

        private let horizontalPadding: CGFloat = 26

        var body: some View {
            HStack {
                Text("Discover")
                    .foregroundStyle(theme.tokens.browseHeaderText)
                    .font(.satoshi.regular.size(34))

                Spacer()

                Button(action: {
                    viewModel.cancelAllDownloads()
                }, label: {
                    Image(systemName: "xmark.circle")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundColor(viewModel.inProgressTracksCount > .zero
                                         ? theme.tokens.clearAllDownloadsActive
                                         : theme.tokens.clearAllDownloadsInactive
                        )
                })
                .disabled(viewModel.inProgressTracksCount == .zero)
            }
            .padding(.horizontal, horizontalPadding)
        }

    }

    private struct ContentView: View {
        @Injected var viewModel: TransferManaging
        @Binding var selectedGenre: Genre
        @Binding var slideDirection: SlideDirection
        @Binding var searchQuery: String

        private let headerLeadingPadding: CGFloat = 26

        var body: some View {
            if let section = viewModel.sections.first(where: { $0.type == .search }) {
                if section.tracks.isNotEmpty, searchQuery.isNotEmpty {
                    ZStack {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 8) {
                                ForEach(section.tracks, id: \.id) { track in
                                    TrackCell(
                                        track: track,
                                        searchQuery: searchQuery
                                    ) {
                                        Task {
                                            await viewModel.handleDownloadAction(for: track)
                                        }
                                    }
                                    .onAppear {
                                        if track === section.tracks.last {
                                            viewModel.loadNextSearch()
                                        }
                                    }
                                }

                                if viewModel.isPaginationSearchLoading {
                                    SpinnerView(size: .regular)
                                        .padding(.top, 8)
                                }

                                PaginationFooterView(
                                    hasReachedEnd: viewModel.reachedSearchTracksEnd,
                                    hasItems: section.tracks.isNotEmpty
                                )
                            }
                        }
                    }
                    .padding(.top, 10)
                    .contentMargins(.bottom, 100)
                } else if section.tracks.isEmpty,
                          searchQuery.count > 2,
                          viewModel.shouldShowCentralSpinner.isFalse,
                          viewModel.completedSearchQuery == searchQuery {
                    ContentUnavailableView(
                        "No tracks found",
                        systemImage: "music.note.list",
                        description: Text("Try searching for another artist or track")
                    )
                }
            } else if viewModel.completedSearchQuery.isEmpty {
                let genreTracksSection = viewModel.sections.first(where: { $0.type == .genre })
                let popularTracksSection = viewModel.sections.first(where: { $0.type == .popular })

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        SegmentedChipControl(
                            selected: $selectedGenre,
                            direction: $slideDirection,
                            items: Genre.allCases
                        )
                        .padding(.top, 10)

                        if genreTracksSection?.tracks.isEmpty == true,
                           popularTracksSection?.tracks.isEmpty == true,
                           viewModel.shouldShowCentralSpinner.isFalse {
                            ContentUnavailableView(
                                "Connection issue",
                                systemImage: "wifi.slash",
                                description: Text("Check your internet connection")
                            )
                        } else {
                            if viewModel.shouldShowCentralSpinner.isFalse {
                                if let section = genreTracksSection, section.tracks.isNotEmpty {
                                        Section {
                                            ZStack {
                                                ScrollViewReader { horizontalProxy in
                                                    ScrollView(.horizontal, showsIndicators: false) {
                                                        LazyHStack(spacing: 8) {
                                                            ForEach(section.tracks, id: \.id) { track in
                                                                GenreCell(track: track) {
                                                                    Task {
                                                                        await viewModel.handleDownloadAction(for: track)
                                                                    }
                                                                }
                                                                .onAppear {
                                                                    if track === section.tracks.last {
                                                                        viewModel.loadNextBy(genre: selectedGenre)
                                                                    }
                                                                }
                                                            }

                                                            if viewModel.isPaginationGenreLoading {
                                                                SpinnerView(size: .regular)
                                                                    .padding(.leading, 8)
                                                            }

                                                            PaginationFooterView(
                                                                hasReachedEnd: viewModel.reachedGenreTracksEnd,
                                                                hasItems: section.tracks.isNotEmpty,
                                                                style: .carousel
                                                            )
                                                        }
                                                        .padding(.horizontal)
                                                        .id("featuredLeft")
                                                    }
                                                    .onChange(of: viewModel.isRefreshing) { _, isRefreshing in
                                                        guard isRefreshing.isFalse else { return }

                                                        horizontalProxy.scrollTo("featuredLeft", anchor: .leading)
                                                    }
                                                }
                                            }
                                            .id(selectedGenre)
                                        } header: {
                                            Text(section.title)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.leading, headerLeadingPadding)
                                                .padding(.vertical, 10)
                                                .background(Color(.systemBackground))
                                                .foregroundStyle(Color(.label))
                                                .font(.headline)
                                        }
                                    } else if viewModel.shouldShowCentralSpinner.isFalse {
                                        ContentUnavailableView(
                                            "No featured tracks",
                                            systemImage: "music.note.list",
                                            description: Text("Pull down to refresh")
                                        )
                                    }

                                if let section = popularTracksSection, section.tracks.isNotEmpty {
                                        Section {
                                                LazyVStack(spacing: 4) {
                                                    ForEach(section.tracks, id: \.id) { track in
                                                        TrackCell(track: track) {
                                                            Task {
                                                                await viewModel.handleDownloadAction(for: track)
                                                            }
                                                        }
                                                        .onAppear {
                                                            if track === section.tracks.last {
                                                                viewModel.loadNextPopular()
                                                            }
                                                        }
                                                    }

                                                    if viewModel.isPaginationPopularLoading {
                                                        SpinnerView(size: .regular)
                                                            .padding(.top, 8)
                                                    }

                                                    PaginationFooterView(
                                                        hasReachedEnd: viewModel.reachedPopularTracksEnd,
                                                        hasItems: section.tracks.isNotEmpty
                                                    )
                                                }
                                        } header: {
                                            Text(section.title)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.leading, headerLeadingPadding)
                                                .padding(.vertical, 10)
                                                .background(Color(.systemBackground))
                                                .foregroundStyle(Color(.label))
                                                .font(.headline)
                                        }
                                    } else if viewModel.shouldShowCentralSpinner.isFalse {
                                        ContentUnavailableView(
                                            "No popular tracks",
                                            systemImage: "music.note.list",
                                            description: Text("Pull down to refresh")
                                        )
                                    }
                            }
                        }
                    }
                }
                .padding(.top, 5)
                .refreshable {
                    await viewModel.refreshBrowse(
                        selectedGenre == .all ? nil : selectedGenre
                    )
                }
                .id(selectedGenre)
                .contentMargins(.bottom, 100)
                .onChange(of: selectedGenre) { _, genre in
                    Task {
                        await viewModel.loadFirstBy(genre: genre)
                    }
                }
            }
        }
    }
}

#Preview {
        BrowseView()
}
