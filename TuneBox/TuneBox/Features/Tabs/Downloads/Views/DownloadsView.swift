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
            HeaderView(viewModel: transferManagingVM)

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
        .dismissKeyboardOnTap(focused: $isSearchFieldFocused)
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
        @Environment(\.themeManager) private var theme
        let viewModel: DownloadsPresenting

        private let horizontalPadding: CGFloat = 26

        var body: some View {
            HStack {
                Text("Library")
                    .foregroundStyle(theme.tokens.browseHeaderText)
                    .font(.satoshi.regular.size(34))

                Spacer()

                Menu {
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
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(theme.tokens.browseHeaderText)
                }
            }
            .padding(.horizontal, horizontalPadding)
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
