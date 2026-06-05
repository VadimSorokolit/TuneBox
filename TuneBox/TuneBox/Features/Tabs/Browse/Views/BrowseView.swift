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

            SearchCell(
                searchQuery: $searchQuery,
                isFocused: $isTextFieldFocused) {
                    viewModel.loadSeachBy(query: searchQuery)
                } onClear: {
                    viewModel.clearSearch()
                }

            MainView(selectedGenre: $selectedGenre,
                     slideDirection: $slideDirection
            )
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top
        )
        .onAppear {
            viewModel.loadFirstPopular()
        }
        .onChange(of: viewModel.selectedTab) { _, tab in
            if tab != .browse {
                searchQuery = ""
                isTextFieldFocused = false
                viewModel.clearSearch()
            }
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

    private struct MainView: View {
        @Injected var viewModel: TransferManaging
        @Binding var selectedGenre: Genre
        @Binding var slideDirection: SlideDirection

        private let headerLeadingPadding: CGFloat = 26

        var body: some View {
            VStack(spacing: 0) {
                if viewModel.searchTracks.isEmpty == false {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.searchTracks, id: \.id) { track in
                                TrackCell(track: track) {
                                    Task {
                                        await viewModel.handleDownloadAction(for: track)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 100)
                    }
                } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                                SegmentedChipControl(
                                    items: Genre.allCases,
                                    selected: $selectedGenre,
                                    direction: $slideDirection
                                )
                                .onChange(of: selectedGenre) { _, genre in
                                    viewModel.loadFirstBy(genre: genre)
                                }
                                .padding(.top, 10)

                                if viewModel.genreTracks.isEmpty, viewModel.popularTracks.isEmpty {
                                    ContentUnavailableView(
                                        "Connection issue",
                                        systemImage: "wifi.slash",
                                        description: Text("Check your internet connection")
                                    )
                                } else {
                                if viewModel.genreTracks.isEmpty == false {
                                    Section {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(viewModel.genreTracks, id: \.id) { track in
                                                    GenreCell(track: track) {
                                                        Task {
                                                            await viewModel.handleDownloadAction(for: track)
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
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

                                if viewModel.popularTracks.isEmpty == false {
                                    Section {
                                        VStack(spacing: 4) {
                                            ForEach(viewModel.popularTracks, id: \.id) { track in
                                                TrackCell(track: track) {
                                                    Task {
                                                        await viewModel.handleDownloadAction(for: track)
                                                    }
                                                }
                                            }
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

                                    Color.clear
                                        .padding(.bottom, 100)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}

#Preview {
        BrowseView()
}
