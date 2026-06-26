//
//  BrowsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Resolver
import SwiftUI

struct BrowseView: View {

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

            ContentView(
                slideDirection: $slideDirection,
                viewModel: viewModel
            )
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top
        )
        .task {
            await viewModel.loadInitialContent()
        }
        .task(id: searchQuery) {
            try? await Task.sleep(for: .milliseconds(300))

            if Task.isCancelled {
                return
            }

            handleSearchStateBy(query: searchQuery)
        }
        .dismissKeyboardOnTap(focused: $isSearchFieldFocused)
        .modifier(CentralSpinnerModifier(isVisible: viewModel.shouldShowCentralSpinner))
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: TransferManaging
    @FocusState private var isSearchFieldFocused: Bool
    @State private var slideDirection: SlideDirection = .forward
    @State private var searchQuery: String = ""

    // MARK: - Subviews. Private

    private struct HeaderView: View {
        @Environment(\.themeManager) private var theme
        let viewModel: TransferManaging

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
        @Binding var slideDirection: SlideDirection
        let viewModel: TransferManaging

        private let headerLeadingPadding: CGFloat = 26

        var body: some View {
            ScrollView(
                showsIndicators: false,
                content: {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        SegmentedChipControl(
                            selected: Binding(
                                get: {
                                    viewModel.selectedGenre
                                },
                                set: {
                                    viewModel.selectedGenre = $0
                                }
                            ),
                            direction: $slideDirection,
                            items: Genre.allCases
                        )

                        Group {
                            ForEach(viewModel.sections) { section in
                                switch section.type {
                                    case .search:
                                        searchSectionView(section)

                                    case .genre:
                                        genreSectionView(section)

                                    case .popular:
                                        popularSectionView(section)

                                    case .recents, .all:
                                        EmptyView()
                                }
                            }
                        }
                        .modifier(EmptyTracksStateModifier(showsEmptyState: viewModel.showsEmptyState))
                    }
                }
            )
            .padding(.top, 10)
            .contentMargins(.bottom, 20)
            .refreshable {
                await viewModel.refreshBrowse()
            }
        }

        // MARK: - Methods. Private

        @ViewBuilder
        private func searchSectionView(_ section: TracksSection) -> some View {
            if section.tracks.isNotEmpty,
               viewModel.completedSearchQuery.isNotEmpty,
               viewModel.shouldShowCentralSpinner.isFalse {

                Section(
                    content: {
                        LazyVStack(spacing: 8) {
                            ForEach(section.tracks, id: \.id) { track in
                                TrackCell(
                                    track: track,
                                    searchQuery: viewModel.completedSearchQuery
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
                    },
                    header: {
                        sectionTracksTitle(section.title)
                    }
                )
            }
        }

        @ViewBuilder
        private func genreSectionView(_ section: TracksSection) -> some View {
            if section.tracks.isNotEmpty,
               viewModel.completedSearchQuery.isEmpty,
               viewModel.shouldShowCentralSpinner.isFalse {

                Section(
                    content: {
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
                                                viewModel.loadNextBy(genre: viewModel.selectedGenre)
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
                            .onChange(of: viewModel.selectedGenre) { _, genre in
                                Task {
                                    await viewModel.loadFirstBy(genre: genre)
                                }
                            }
                            .onChange(of: viewModel.isRefreshing) { _, isRefreshing in
                                guard isRefreshing.isFalse else { return }

                                horizontalProxy.scrollTo("featuredLeft", anchor: .leading)
                            }
                            .id(viewModel.selectedGenre)
                        }
                    },
                    header: {
                        sectionTracksTitle(section.title)
                    }
                )
            }
        }

        @ViewBuilder
        private func popularSectionView(_ section: TracksSection) -> some View {
            if section.tracks.isNotEmpty,
               viewModel.completedSearchQuery.isEmpty,
               viewModel.shouldShowCentralSpinner.isFalse {

                Section(
                    content: {
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
                    },
                    header: {
                        sectionTracksTitle(section.title)
                    }
                )
            }
        }
    }

    private struct CentralSpinnerModifier: ViewModifier {
        let isVisible: Bool

        func body(content: Content) -> some View {
            content
                .overlay {
                    if isVisible {
                        SpinnerView()
                    }
                }
        }
    }

    private func handleSearchStateBy(query: String) {
        if query.isEmpty {
            viewModel.clearSearchState()
        }

        if viewModel.completedSearchQuery != query {
            viewModel.loadSearchBy(query: query)
        }
    }
}

#Preview {
    BrowseView()
}
