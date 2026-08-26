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
                slideDirection: $slideDirection,
                rootTabsVM: rootTabsVM,
                transferManagingVM: transferManagingVM,
                playerVM: playerVM,
            )
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top
        )
        .task {
            await transferManagingVM.loadInitialData()
        }
        .task(id: searchQuery) {
            try? await Task.sleep(for: .milliseconds(300))

            if Task.isCancelled {
                return
            }

            handleSearchStateBy(query: searchQuery)
        }
        .dismissKeyboardOnTap(focused: $isSearchFieldFocused)
        .modifier(CentralSpinnerModifier(isVisible: transferManagingVM.shouldShowCentralSpinner))
    }

    // MARK: - Properties. Private

    @Injected private var rootTabsVM: RootTabsManaging
    @Injected private var transferManagingVM: TransferManaging
    @Injected private var playerVM: PlayerManaging
    @FocusState private var isSearchFieldFocused: Bool
    @State private var slideDirection: SlideDirection = .forward
    @State private var searchQuery: String = ""

    // MARK: - Subviews. Private

    private struct HeaderView: View {

        // MARK: - Properties. Public

        @Environment(\.themeManager) private var theme

        let transferManagingVM: TransferManaging

        // MARK: - Body

        var body: some View {
            HStack {
                Text("Discover")
                    .foregroundStyle(theme.tokens.browseHeaderText)
                    .font(.satoshi.regular.size(34))

                Spacer()

                Menu {
                    Button(action: {
                        transferManagingVM.cancelAllActiveDownloads()
                    }, label: {
                        Label("Remove all active tracks", systemImage: "")
                    })
                    .disabled(transferManagingVM.inProgressActiveTracksCount == .zero)

                    Button(action: {
                        transferManagingVM.cancelAllPausedDownloads()
                    }, label: {
                        Label("Remove all paused tracks", systemImage: "")
                    })
                    .disabled(transferManagingVM.inProgressPausedTracksCount == .zero)
                } label: {
                    Image(systemName: "xmark.circle")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 30, weight: .ultraLight))
                }
                .disabled(
                    transferManagingVM.inProgressActiveTracksCount == .zero
                    && transferManagingVM.inProgressPausedTracksCount == .zero
                )
                .opacity(
                    transferManagingVM.inProgressActiveTracksCount == .zero
                    && transferManagingVM.inProgressPausedTracksCount == .zero
                    ? 0.5
                    : 1
                )
            }
            .padding(.horizontal, horizontalPadding)
        }

        // MARK: - Properties. Private

        private let horizontalPadding: CGFloat = 26
    }

    private struct ContentView: View {

        // MARK: - Properties. Public

        @Binding var slideDirection: SlideDirection

        let rootTabsVM: RootTabsManaging
        let transferManagingVM: TransferManaging
        let playerVM: PlayerManaging

        // MARK: - Body

        var body: some View {
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    SegmentedChipControl(
                        selected: Binding(
                            get: {
                                transferManagingVM.selectedGenre
                            },
                            set: {
                                transferManagingVM.selectGenre($0)
                            }
                        ),
                        direction: $slideDirection,
                        items: Genre.allCases
                    )

                    Group {
                        ForEach(transferManagingVM.sections) { section in
                            switch section.type {
                                case .search:
                                    searchSectionView(section)

                                case .genre:
                                    genreSectionView(section)

                                case .popular:
                                    popularSectionView(section)

                                case .recents, .all, .imported:
                                    EmptyView()
                            }
                        }
                    }
                    .modifier(EmptyTracksStateModifier(showsEmptyState: transferManagingVM.showsEmptyState))
                }
            }
            .padding(.top, 10)
            .bottomContentMargin(0, 0, isPlayerVisible: playerVM.isPlayerVisible, isTabBarVisible: rootTabsVM.isTabBarVisible)
            .refreshable {
                await transferManagingVM.refreshBrowse()
            }
        }

        // MARK: - Properties. Private

        private let headerLeadingPadding: CGFloat = 26

        // MARK: - Methods. Private

        @ViewBuilder
        private func searchSectionView(_ section: TracksSection) -> some View {
            if section.tracks.isNotEmpty,
               transferManagingVM.completedSearchQuery.isNotEmpty,
               transferManagingVM.shouldShowCentralSpinner.isFalse {

                Section(
                    content: {
                        LazyVStack(spacing: 8) {
                            ForEach(section.tracks, id: \.id) { track in
                                TrackCell(
                                    track: track,
                                    searchQuery: transferManagingVM.completedSearchQuery,
                                    onButtonTap: {
                                        Task {
                                            await transferManagingVM.handleDownloadAction(for: track)
                                        }
                                    }
                                )
                                .onAppear {
                                    if track === section.tracks.last {
                                        transferManagingVM.loadNextSearch()
                                    }
                                }
                            }

                            if transferManagingVM.isPaginationSearchLoading {
                                SpinnerView(size: .regular)
                                    .padding(.top, 14)
                                    .padding(.bottom, 20)
                            }

                            PaginationFooterView(
                                hasReachedEnd: transferManagingVM.reachedSearchTracksEnd,
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
               transferManagingVM.completedSearchQuery.isEmpty,
               transferManagingVM.shouldShowCentralSpinner.isFalse {

                Section(
                    content: {
                        ScrollViewReader { horizontalProxy in
                            ScrollView(.horizontal, showsIndicators: true) {
                                LazyHStack(spacing: 8) {
                                    ForEach(section.tracks, id: \.id) { track in
                                        GenreCell(
                                            track: track,
                                            onButtonTap: {
                                                Task {
                                                    await transferManagingVM.handleDownloadAction(for: track)
                                                }
                                            }
                                        )
                                        .onAppear {
                                            if track === section.tracks.last {
                                                transferManagingVM.loadNextBy(genre: transferManagingVM.selectedGenre)
                                            }
                                        }
                                    }

                                    if transferManagingVM.isPaginationGenreLoading {
                                        SpinnerView(size: .regular)
                                            .padding(.vertical, 10)
                                    }

                                    PaginationFooterView(
                                        hasReachedEnd: transferManagingVM.reachedGenreTracksEnd,
                                        hasItems: section.tracks.isNotEmpty,
                                        style: .carousel
                                    )
                                }
                                .padding(.bottom, 12)
                                .padding(.horizontal)
                                .id("featuredLeft")
                            }
                            .onChange(of: transferManagingVM.isRefreshing) { _, isRefreshing in
                                guard isRefreshing.isFalse else { return }

                                horizontalProxy.scrollTo("featuredLeft", anchor: .leading)
                            }
                            .id(transferManagingVM.selectedGenre)
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
               transferManagingVM.completedSearchQuery.isEmpty,
               transferManagingVM.shouldShowCentralSpinner.isFalse {

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
                                .onAppear {
                                    if track === section.tracks.last {
                                        transferManagingVM.loadNextPopular()
                                    }
                                }
                            }

                            if transferManagingVM.isPaginationPopularLoading {
                                SpinnerView(size: .regular)
                                    .padding(.top, 14)
                                    .padding(.bottom, 20)
                            }

                            PaginationFooterView(
                                hasReachedEnd: transferManagingVM.reachedPopularTracksEnd,
                                hasItems: section.tracks.isNotEmpty
                            )
                        }
                    },
                    header: {
                        sectionTracksTitle(section.title)
                    }
                )
                .padding(.top, -3)
            }
        }
    }

    private func handleSearchStateBy(query: String) {
        if query.isEmpty {
            transferManagingVM.clearSearchState()
        }

        if transferManagingVM.completedSearchQuery != query {
            transferManagingVM.loadSearchBy(query: query)
        }
    }
}

#Preview {
    BrowseView()
}
