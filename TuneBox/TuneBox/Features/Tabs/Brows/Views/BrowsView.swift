//
//  BrowsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Resolver
import SwiftUI

struct BrowsView: View {
    @Injected var viewModel: TransferManaging
    @FocusState private var isTextFieldFocused: Bool
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

            MainView()
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top
        )
        .onAppear {
            viewModel.loadFirstPopular()
        }
        .onChange(of: viewModel.selectedTab) { _, tab in
            if tab != .brows {
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
            .padding(.horizontal)
        }

    }

    private struct SearchView: View {

        var body: some View {
            Text("")
                .padding(.top, 10)
        }

    }

    private struct MainView: View {
        @Injected var viewModel: TransferManaging

        var body: some View {
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
                }
                .padding(.top, 15)
            } else {
                if viewModel.popularTracks.isEmpty == false {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.popularTracks, id: \.id) { track in
                                TrackCell(track: track) {
                                    Task {
                                        await viewModel.handleDownloadAction(for: track)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 15)
                }
            }

            Spacer()
        }
    }

}

#Preview {
        BrowsView()
}
