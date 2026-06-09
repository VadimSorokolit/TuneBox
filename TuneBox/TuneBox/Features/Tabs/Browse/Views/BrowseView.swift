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
        .onAppear {
            guard viewModel.popularTracks.isEmpty,
                  viewModel.genreTracks.isEmpty else {
                return
            }

            viewModel.loadFirstPopular()
            viewModel.loadFirstBy(genre: nil)
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
                    .foregroundStyle(theme.tokens.browsHeaderText)
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
            if viewModel.searchTracks.isNotEmpty, searchQuery.isNotEmpty {
                ZStack {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.searchTracks, id: \.id) { track in
                                TrackCell(
                                    track: track,
                                    searchQuery: searchQuery
                                ) {
                                    Task {
                                        await viewModel.handleDownloadAction(for: track)
                                    }
                                }
                                .onAppear {
                                    if track === viewModel.searchTracks.last {
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
                                hasItems: viewModel.searchTracks.isNotEmpty
                            )
                        }
                    }
                }
                .padding(.top, 10)
                .contentMargins(.bottom, 100)
            } else if viewModel.searchTracks.isEmpty,
                      searchQuery.count > 2,
                      viewModel.shouldShowCentralSpinner.isFalse,
                      viewModel.completedSearchQuery == searchQuery {
                    ContentUnavailableView(
                        "No tracks found",
                        systemImage: "music.note.list",
                        description: Text("Try searching for another artist or track")
                    )
            } else if viewModel.completedSearchQuery.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        SegmentedChipControl(
                            items: Genre.allCases,
                            selected: $selectedGenre,
                            direction: $slideDirection
                        )
                        .padding(.top, 10)
                        if viewModel.genreTracks.isEmpty,
                           viewModel.popularTracks.isEmpty,
                           viewModel.shouldShowCentralSpinner.isFalse {
                            ContentUnavailableView(
                                "Connection issue",
                                systemImage: "wifi.slash",
                                description: Text("Check your internet connection")
                            )
                        } else {
                            if viewModel.shouldShowCentralSpinner.isFalse {
                                if viewModel.genreTracks.isNotEmpty {
                                    Section {
                                        ZStack {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                LazyHStack(spacing: 8) {
                                                    ForEach(viewModel.genreTracks, id: \.id) { track in
                                                        GenreCell(track: track) {
                                                            Task {
                                                                await viewModel.handleDownloadAction(for: track)
                                                            }
                                                        }
                                                        .onAppear {
                                                            if track === viewModel.genreTracks.last {
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
                                                        hasItems: viewModel.genreTracks.isNotEmpty,
                                                        style: .carousel
                                                    )
                                                }
                                                .padding(.horizontal)
                                            }

                                            if viewModel.isGenreFirstLoading {
                                                SpinnerView()
                                            }
                                        }
                                        .id(selectedGenre)
                                    } header: {
                                        Text("Featured")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.leading, headerLeadingPadding)
                                            .padding(.vertical, 10)
                                            .background(Color(.systemBackground))
                                            .foregroundStyle(Color(.label))
                                            .font(.headline)
                                    }
                                }

                                if viewModel.popularTracks.isNotEmpty {
                                    Section {
                                        LazyVStack(spacing: 4) {
                                            ForEach(viewModel.popularTracks, id: \.id) { track in
                                                TrackCell(track: track) {
                                                    Task {
                                                        await viewModel.handleDownloadAction(for: track)
                                                    }
                                                }
                                                .onAppear {
                                                    if track === viewModel.popularTracks.last {
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
                                                hasItems: viewModel.popularTracks.isNotEmpty
                                            )
                                        }
                                    } header: {
                                        Text("Popular")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.leading, headerLeadingPadding)
                                            .padding(.vertical, 10)
                                            .background(Color(.systemBackground))
                                            .foregroundStyle(Color(.label))
                                            .font(.headline)
                                    }
                                }
                            }
                        }
                    }
                }
                .id(selectedGenre)
                .contentMargins(.bottom, 100)
                .onChange(of: selectedGenre) { _, genre in
                    viewModel.loadFirstBy(genre: genre)
                }
            }
            }
//            .refreshable {
//                if viewModel.searchTracks.isNotEmpty {
//                    viewModel.loadSearchBy(query: viewModel.searchQuery)
//                } else {
//                    viewModel.loadFirstPopular()
//                    if selectedGenre != .all {
//                        viewModel.loadFirstBy(genre: selectedGenre)
//                    } else {
//                        viewModel.loadFirstBy(genre: nil)
//                    }
//                }
//            }
//        }
    }

}

#Preview {
        BrowseView()
}
