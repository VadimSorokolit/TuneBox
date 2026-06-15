//
//  DownloadsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import SwiftUI

struct DownloadsView: View {
    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedSection: TracksSection.SectionType = .activeDownloads
    @State private var searchQuery: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(selectedSection: $selectedSection)

            SearchBarView(
                searchQuery: $searchQuery,
                isFocused: $isTextFieldFocused,
                onSubmit: {},
                onClear: {}
            )

            ContentView()
        }
    }

    private struct HeaderView: View {
        @Environment(\.themeManager) private var theme
        @Binding var selectedSection: TracksSection.SectionType

        private let horizontalPadding: CGFloat = 26

        var body: some View {
            HStack {
                Text("My Downloads")
                    .foregroundStyle(theme.tokens.browseHeaderText)
                    .font(.satoshi.regular.size(34))

                Spacer()

                Menu(content: {
                    Button {
                        selectedSection = .activeDownloads
                    } label: {
                        Label(
                            "Active Downloads",
                            systemImage: selectedSection == .activeDownloads
                            ? "checkmark"
                            : ""
                        )
                    }

                    Button {
                        selectedSection = .downloaded
                    } label: {
                        Label(
                            "Downloaded",
                            systemImage: selectedSection == .downloaded
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

        var body: some View {
            Text("ContentView")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    DownloadsView()
}
