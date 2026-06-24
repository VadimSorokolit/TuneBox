//
//  DownloadsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import SwiftUI
import Resolver

enum TracksType: Hashable, Equatable {
    case active
    case downloaded
}

struct DownloadsView: View {
    @Injected private var viewModel: DownloadsPresenting
    @FocusState private var isTextFieldFocused: Bool
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
                }
            )

            ContentView()
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top
        )
        .onAppear {
            viewModel.startObservingTracksChanges()
        }
        .task(id: viewModel.selectedTracksType) {
            await viewModel.fetchTracksSectionBy(viewModel.selectedTracksType)
        }
        .task(id: searchQuery) {
            try? await Task.sleep(for: .milliseconds(300))

            await viewModel.handleSearchQuery(searchQuery)
        }
        .onTapGesture {
            isTextFieldFocused = false
        }
    }

    private struct HeaderView: View {
        @Injected private var viewModel: DownloadsPresenting
        @Environment(\.themeManager) private var theme

        private let horizontalPadding: CGFloat = 26

        var body: some View {
            HStack {
                Text("Library")
                    .foregroundStyle(theme.tokens.browseHeaderText)
                    .font(.satoshi.regular.size(34))

                Spacer()

                Menu(content: {
                    Button {
                        viewModel.setType(.active)
                    } label: {
                        Label(
                            "Active Downloads",
                            systemImage: viewModel.selectedTracksType == .active
                            ? "checkmark"
                            : ""
                        )
                    }

                    Button {
                        viewModel.setType(.downloaded)
                    } label: {
                        Label(
                            "Downloaded",
                            systemImage: viewModel.selectedTracksType == .downloaded
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

        private let headerLeadingPadding: CGFloat = 26

        var body: some View {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(viewModel.sections) { section in
                        Section {
                            sectionContent(section)
                        } header: {
                            sectionHeader(for: section)
                        }
                    }
                }
            }
            .padding(.top, 5)
            .contentMargins(.bottom, 20)
            .modifier(EmptyTracksStateModifier(showsEmptyState: viewModel.showsEmptyState))
        }

        @ViewBuilder
        private func sectionContent(_ section: TracksSection) -> some View {
            switch section.type {
                case .search:
                    searchSection(section)
                case .recent:
                    recentSection(section)
                case .all:
                    filteredSection(section)

                case .genre, .popular:
                    EmptyView()
            }
        }

        @ViewBuilder
        private func searchSection(_ section: TracksSection) -> some View {
            if section.type == .search, section.tracks.isEmpty.isFalse, viewModel.isSearchMode {
                LazyVStack(spacing: 4) {
                    ForEach(section.tracks, id: \.id) { track in
                        TrackCell(
                            track: track,
                            searchQuery: viewModel.completedSearchQuery,
                            onTap: {
                                Task {
                                    await viewModel.handleDownloadAction(for: track)
                                }
                            })
                    }
                }
            }
        }

        @ViewBuilder
        private func recentSection(_ section: TracksSection) -> some View {
            if section.type == .recent, section.tracks.isEmpty.isFalse, viewModel.isSearchMode.isFalse {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 4) {
                        ForEach(section.tracks, id: \.id) { track in
                            GenreCell(track: track) {
                                Task { await viewModel.handleDownloadAction(for: track) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }

        @ViewBuilder
        private func filteredSection(_ section: TracksSection) -> some View {
            if section.type == .all, section.tracks.isEmpty.isFalse, viewModel.isSearchMode.isFalse {
                LazyVStack(spacing: 4) {
                    ForEach(section.tracks, id: \.id) { track in
                        TrackCell(track: track) {
                            Task {
                                await viewModel.handleDownloadAction(for: track)
                            }
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private func sectionHeader(for section: TracksSection) -> some View {
            switch section.type {
                case .search:
                    if section.type == .search, section.tracks.isEmpty.isFalse, viewModel.isSearchMode {
                        customTitle(for: section)
                    }

                case .recent:
                    if section.type == .recent, section.tracks.isEmpty.isFalse, viewModel.isSearchMode.isFalse {
                        customTitle(for: section)
                    }

                case .all:
                    if section.type == .all, section.tracks.isEmpty.isFalse, viewModel.isSearchMode.isFalse {
                        customTitle(for: section, suffix: viewModel.sectionTitleSuffix)
                    }

                case .genre, .popular:
                    EmptyView()
            }
        }

        @ViewBuilder
        private func customTitle(for section: TracksSection, suffix: String? = nil) -> some View {
            Text("\(section.title) \(suffix ?? "")")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, headerLeadingPadding)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .foregroundStyle(Color(.label))
                .font(.headline)
        }
    }

    private struct EmptyTracksStateModifier: ViewModifier {
        let showsEmptyState: Bool

        func body(content: Content) -> some View {
            if showsEmptyState {
                ContentUnavailableView(
                    "No Tracks",
                    systemImage: "music.note"
                )
            } else {
                content
            }
        }
    }
}

#Preview {
    DownloadsView()
}
