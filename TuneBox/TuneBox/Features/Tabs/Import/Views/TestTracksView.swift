//
//  TestTracksView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.07.2026.
//

import SwiftUI
import Resolver

struct TestTracksView: View {

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 20) {
            HeaderView(
                isFileImporterPresented: $isFileImporterPresented,
                viewModel: viewModel
            )

            if viewModel.hasLibrary {
                ContentView(
                    viewModel: viewModel
                )
            } else {
                EmptyContentView(
                    isFileImporterPresented: $isFileImporterPresented
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.gray.opacity(0.025))
        .task {
            if viewModel.hasLibrary.isFalse {
                await viewModel.fetchImportedTracks()
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.folder],
            onCompletion: { result in
                switch result {
                    case .success(let url):
                        Task {
                            await viewModel.importFolder(url)
                        }

                    case .failure(let error):
                        AppLogger.imported.warning("\(error.localizedDescription)")
                }
            }
        )
        .modifier(CentralSpinnerModifier(isVisible: viewModel.isLoading))
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: TestManaging
    @State private var isFileImporterPresented: Bool = false

    // MARK: - Objects. Private

    private struct HeaderView: View {

        // MARK: - Properties. Public

        @Binding var isFileImporterPresented: Bool
        let viewModel: TestManaging

        // MARK: - Body

        var body: some View {
            HStack {
                Spacer()

                if viewModel.editSectionModeEnabled {
                    Button(
                        action: {
                            viewModel.finishEditSections()
                        }, label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: imageFontSize, weight: .medium))
                                .foregroundStyle(Color.black.opacity(foregroundOpacity))
                                .frame(size: imageSize)
                                .glassEffect(in: .circle)
                        }
                    )
                } else {
                    Menu {
                        Button(
                            action: {
                                isFileImporterPresented = true
                            }, label: {
                                Label("Add Folder", systemImage: "plus")
                            }
                        )

                        Button(
                            action: {
                                viewModel.beginEditSections()
                            }, label: {
                                Label("Edit Sections", systemImage: "slider.horizontal.3")
                            }
                        )
                    } label: {
                        Image(systemName: "ellipsis")
                        .font(.system(size: imageFontSize, weight: .medium))
                        .foregroundStyle(Color.black.opacity(foregroundOpacity))
                        .frame(size: imageSize)
                        .glassEffect(in: .circle)
                    }
                    .disabled(isMenuButtonDisabled)
                    .opacity(isMenuButtonDisabled ? 0 : 1)
                }
            }
            .padding(.horizontal, horizontalPadding)
        }

        // MARK: - Propertis. Private

        private let imageFontSize: CGFloat = 20
        private let imageSize: CGFloat = 44
        private let horizontalPadding: CGFloat = 20
        private let foregroundOpacity: Double = 0.6

        private var isMenuButtonDisabled: Bool {
            viewModel.hasLibrary.isFalse
        }
    }

    private struct EmptyContentView: View {

        // MARK: - Properties. Public

        @Binding var isFileImporterPresented: Bool

        // MARK: - Body

        var body: some View {
            ContentUnavailableView {
                Label("No Tracks", systemImage: "music.note.list")
            } description: {
                Text("Your music library will appear here\n once you add your some folders")
            } actions: {
                Button(
                    action: {
                        isFileImporterPresented = true
                    }, label: {
                        HStack {
                            Image(systemName: "plus")

                            Text("Add Folder")
                        }
                        .foregroundStyle(.black.opacity(0.6))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.gray.opacity(0.2))
                        )
                    }
                )
            }

        }
    }

    private struct ContentView: View {

        // MARK: - Properties. Public

        @Environment(AppCoordinator.self) private var coordinator
        let viewModel: TestManaging

        // MARK: - Body

        var body: some View {
            if let library = viewModel.library {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                        ForEach(viewModel.sections) { section in
                            Section {
                                switch section.kind {
                                    case .library:
                                        VStack(spacing: 0) {
                                            ForEach(section.items, id: \.self) { item in
                                                LibraryMenuCell(
                                                    item: item,
                                                    isEditMode: viewModel.editSectionModeEnabled,
                                                    isSelected: {
                                                        if case let .library(libraryItem) = item {
                                                            return viewModel.isLibraryItemSelected(libraryItem)
                                                        }
                                                        return false
                                                    }(),
                                                    viewModel: viewModel,
                                                    onTapGesture: {
                                                        if case let .library(libraryItem) = item {
                                                            if viewModel.editSectionModeEnabled {
                                                                viewModel.toggleLibraryItem(libraryItem)
                                                            } else {
                                                                switch libraryItem {
                                                                    case .albums:
                                                                        coordinator.push(.albums)

                                                                    case .artists:
                                                                        coordinator.push(.artist)

                                                                    case .tracks:
                                                                        coordinator.push(.tracks)

                                                                    case .playlists:
                                                                        coordinator.push(.playlists)
                                                                }
                                                            }
                                                        }
                                                    }
                                                )
                                            }
                                        }

                                    case .sources:
                                        EmptyView()
                                }
                            } header: {
                                sectionTracksTitle(section.kind.rawValue.capitalized)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TestTracksView()
}
