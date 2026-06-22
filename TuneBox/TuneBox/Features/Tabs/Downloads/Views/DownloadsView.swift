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

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(selectedTracksType: $selectedTracksType)

            SearchBarView(
                searchQuery: $searchQuery,
                isFocused: $isTextFieldFocused,
                onSubmit: {},
                onClear: {}
            )

            ContentView(selectedTracksType: $selectedTracksType)
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top
        )
        .task(id: selectedTracksType) {
            viewModel.startObservingTracksChanges()
            viewModel.set(selectedTracksType)
            await viewModel.fetchTracksSection()
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

        private let headerLeadingPadding: CGFloat = 26

        var sectionSuffix: String {
            selectedTracksType == .downloaded
            ? "(downloaded)"
            : "(in progress)"
        }

        var body: some View {
            if viewModel.sections.flatMap(\.tracks).isEmpty {
                ContentUnavailableView(
                    "No Tracks",
                    systemImage: "music.note"
                )
            } else {
                let recent = viewModel.sections.first(where: { $0.type == .recent })
                let all = viewModel.sections.first(where: { $0.type == .all })

                if recent?.tracks.count == all?.tracks.count {
                    if let section = recent {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
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
                        .contentMargins(.bottom, 100)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            if let section = recent, section.tracks.isNotEmpty {
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

                            if let section = all, section.tracks.isNotEmpty {
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
                    .padding(.top, 10)
                    .contentMargins(.bottom, 100)
                }
            }
        }
    }
}

#Preview {
    DownloadsView()
}
