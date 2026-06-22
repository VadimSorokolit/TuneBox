//
//  DownloadsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import SwiftUI
import Resolver

enum TracksType {
    case active
    case downloaded
}

struct DownloadsView: View {
    @Injected private var viewModel: DownloadsPresenting
    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedTracksType: TracksType = .active
    @State private var searchQuery: String = ""
    @State private var isSearchMode: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(selectedTracksType: $selectedTracksType)

            SearchBarView(
                searchQuery: $searchQuery,
                isFocused: $isTextFieldFocused,
                onSubmit: {
                    isTextFieldFocused = false
                },
                onClear: {
                    viewModel.clearSearchState()
                    isSearchMode = false
                }
            )

            ContentView(
                selectedTracksType: $selectedTracksType,
                searchQuery: $searchQuery,
                isSearchMode: $isSearchMode
            )
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top
        )
        .task(id: selectedTracksType) {
            viewModel.startObservingTracksChanges()
            searchQuery = viewModel.completedSearchQuery

            let tracks = viewModel.sections
                .filter { $0.type != .search }
                .flatMap(\.tracks)

            guard tracks.isEmpty else {
                return
            }

            await viewModel.fetchTracksSection()
        }
        .task(id: searchQuery) {
            try? await Task.sleep(for: .milliseconds(300))

            if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.clearSearchState()
                isSearchMode = false
            } else {
                if searchQuery != viewModel.completedSearchQuery,
                   searchQuery.count > 2 {
                    isSearchMode = true
                    viewModel.loadSearchBy(query: searchQuery)
                }
            }
        }
        .onTapGesture {
            isTextFieldFocused = false
        }
    }

    private struct HeaderView: View {
        @Environment(\.themeManager) private var theme
        @Binding var selectedTracksType: TracksType

        private let horizontalPadding: CGFloat = 26

        var body: some View {
            HStack {
                Text("Library")
                    .foregroundStyle(theme.tokens.browseHeaderText)
                    .font(.satoshi.regular.size(34))

                Spacer()

                Menu(content: {
                    Button {
                        selectedTracksType = .active
                    } label: {
                        Label(
                            "Active Downloads",
                            systemImage: selectedTracksType == .active
                            ? "checkmark"
                            : ""
                        )
                    }

                    Button {
                        selectedTracksType = .downloaded
                    } label: {
                        Label(
                            "Downloaded",
                            systemImage: selectedTracksType == .downloaded
                            ? "checkmark"
                            : ""
                        )
                    }
                }, label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.tokens.browseHeaderText)
                })
            }
            .padding(.horizontal, horizontalPadding)
        }
    }

    private struct ContentView: View {
        @Injected private var viewModel: DownloadsPresenting
        @Binding var selectedTracksType: TracksType
        @Binding var searchQuery: String
        @Binding var isSearchMode: Bool

        private let headerLeadingPadding: CGFloat = 26

        private var sectionSuffix: String {
            selectedTracksType == .downloaded
            ? "(downloaded)"
            : "(in progress)"
        }

        private var visibleSections: [TracksSection] {
            let searchSection = viewModel.sections.first(where: { $0.type == .search })

            let hasSearchResults = (searchSection?.tracks.isEmpty == false)
            let shouldShowSearch = isSearchMode && hasSearchResults

            if shouldShowSearch {
                return viewModel.sections.filter {
                    $0.type == .search && !$0.tracks.isEmpty
                }
            } else if isSearchMode && !hasSearchResults {
                return []
            } else {
                return viewModel.sections.filter {
                    $0.type != .search
                }
            }
        }

        var body: some View {
            if visibleSections
                .allSatisfy({ $0.tracks.isEmpty }) {
                ContentUnavailableView(
                    "No Tracks",
                    systemImage: "music.note"
                )
            } else {
                ScrollView(showsIndicators: false) {
                    ForEach(visibleSections, id: \.type) { section in
                        if section.type == .search {
                            searchList(section)
                        } else {
                            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                                if section.type == .recent, section.tracks.isNotEmpty {
                                    recentList(section)
                                }

                                if section.type == .all, section.tracks.isNotEmpty {
                                    allList(section)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .contentMargins(.bottom, 100)
            }
        }

        @ViewBuilder
        private func searchList(_ section: TracksSection) -> some View {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    LazyVStack(spacing: 4) {
                        ForEach(section.tracks, id: \.id) { track in
                            TrackCell(
                                track: track,
                                searchQuery: searchQuery,
                                onTap: {
                                    Task {
                                        await viewModel.handleDownloadAction(for: track)
                                    }
                                })
                        }
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
            }
        }

        @ViewBuilder
        private func recentList(_ section: TracksSection) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(section.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, headerLeadingPadding)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))
                    .foregroundStyle(Color(.label))
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 4) {
                        ForEach(section.tracks, id: \.id) { track in
                            GenreCell(track: track) {
                                Task {
                                    await viewModel.handleDownloadAction(for: track)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }

        @ViewBuilder private func allList(_ section: TracksSection) -> some View {
            Section {
                LazyVStack(spacing: 4) {
                    ForEach(section.tracks, id: \.id) { track in
                        TrackCell(track: track) {
                            Task {
                                await viewModel.handleDownloadAction(for: track)
                            }
                        }
                    }
                }
            } header: {
                Text("\(section.title) \(sectionSuffix)")
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

#Preview {
    DownloadsView()
}
