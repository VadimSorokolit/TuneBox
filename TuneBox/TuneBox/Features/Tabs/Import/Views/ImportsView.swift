//
//  ImportsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.07.2026.
//

import SwiftUI
import Resolver

struct ImportsView: View {

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
        .onAppear {
            Task {
                viewModel.startObservingTracksChanges()
                await viewModel.refreshLibrary()
            }
        }
        .onDisappear {
            viewModel.stopObservingTracksChanges()
        }
        .task {
            if viewModel.hasLibrary.isFalse {
                await viewModel.refreshLibrary()
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
        .onChange(of: viewModel.error) { _, newValue in
            isErrorPresented = newValue != nil
        }
        .alert("Error", isPresented: $isErrorPresented) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.error ?? "")
        }
        .modifier(CentralSpinnerModifier(isVisible: viewModel.isLoading))
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: ImportManaging
    @State private var isFileImporterPresented: Bool = false
    @State private var isErrorPresented = false

    // MARK: - Objects. Private

    private struct HeaderView: View {

        // MARK: - Properties. Public

        @Binding var isFileImporterPresented: Bool
        let viewModel: ImportManaging

        // MARK: - Body

        var body: some View {
            HStack {
                Spacer()

                if viewModel.isEditSectionModeEnabled {
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
        let viewModel: ImportManaging

        // MARK: - Body

        var body: some View {
            if viewModel.hasVisibleItems {
                ScrollView {
                    LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                        ForEach(viewModel.sections) { section in
                            Section {
                                switch section.kind {
                                    case .library:
                                        VStack(spacing: 0) {
                                            ForEach(section.items, id: \.self) { item in
                                                LibraryMenuCell(
                                                    title: title(for: item),
                                                    icon: icon(for: item),
                                                    dragID: dragID(for: item),
                                                    isEditMode: viewModel.isEditSectionModeEnabled,
                                                    isSelected: viewModel.isItemSelected(item),
                                                    showsChevron: {
                                                        if case .source = item {
                                                            return viewModel.isEditSectionModeEnabled.isFalse
                                                        }
                                                        return false
                                                    }(),
                                                    onTapGesture: {
                                                        if viewModel.isEditSectionModeEnabled {
                                                            viewModel.toggleItem(item)
                                                        } else {
                                                            switch item {
                                                                case .library(.albums):
                                                                    coordinator.push(.albums)

                                                                case .library(.artists):
                                                                    coordinator.push(.artists)

                                                                case .library(.tracks):
                                                                    coordinator.push(.tracks())

                                                                case .library(.playlists):
                                                                    coordinator.push(.playlists)

                                                                case .source:
                                                                    break
                                                            }
                                                        }
                                                    },
                                                    onDragStarted: {
                                                        viewModel.draggingItem = item
                                                    },
                                                    onDropEntered: {
                                                        viewModel.moveItem(to: item)
                                                    },
                                                    onDropEnded: {
                                                        viewModel.draggingItem = nil
                                                    }
                                                )
                                            }
                                        }

                                    case .sources:
                                        VStack(spacing: 0) {
                                            ForEach(section.items, id: \.self) { item in
                                                LibraryMenuCell(
                                                    title: title(for: item),
                                                    icon: icon(for: item),
                                                    dragID: dragID(for: item),
                                                    isEditMode: viewModel.isEditSectionModeEnabled,
                                                    isSelected: viewModel.isItemSelected(item),
                                                    showsChevron: {
                                                        if case .source = item {
                                                            return viewModel.isEditSectionModeEnabled.isFalse
                                                        }
                                                        return false
                                                    }(),
                                                    onTapGesture: {
                                                        if viewModel.isEditSectionModeEnabled {
                                                            viewModel.toggleItem(item)
                                                        } else {
                                                            switch item {
                                                                case .source(let id):
                                                                    Task {
                                                                        guard let source = viewModel.source(for: id) else {
                                                                            return
                                                                        }
                                                                        switch source.kind {
                                                                            case .api:
                                                                                coordinator.push(.tracks(onlyAPI: true))

                                                                            case .local, .sync:
                                                                                if await viewModel.fetchfolderItems(
                                                                                    sourceID: id, path: nil) != nil {
                                                                                    coordinator.push(.sourceFolder(sourceID: id, path: nil))
                                                                                }
                                                                        }
                                                                    }

                                                                default:
                                                                    break
                                                            }
                                                        }
                                                    },
                                                    onDragStarted: {
                                                        viewModel.draggingItem = item
                                                    },
                                                    onDropEntered: {
                                                        viewModel.moveItem(to: item)
                                                    },
                                                    onDropEnded: {
                                                        viewModel.draggingItem = nil
                                                    }
                                                )
                                            }
                                        }
                                }
                            } header: {
                                switch section.kind {
                                    case .library:
                                        if section.items.isEmpty {
                                            EmptyView()
                                        } else {
                                            sectionTracksTitle(
                                                section.kind.rawValue.capitalized,
                                                foregroundStyle: .gray
                                            )
                                        }

                                    case .sources:
                                        if section.items.isEmpty {
                                            EmptyView()
                                        } else {
                                            sectionTracksTitle(
                                                section.kind.rawValue.capitalized,
                                                foregroundStyle: .gray
                                            )
                                        }
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Text("Nothing to Show")
                        .font(.system(size: 24, weight: .bold))
                } description: {
                    Text("Enable some sections to brows your library")
                        .padding(.top, 10)
                } actions: {
                    Button(action: {
                        viewModel.beginEditSections()
                    }, label: {
                        Text("Edit Sections")
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

        // MARK: - Private. Methods

        private func title(for item: ImportItem) -> String {
            switch item {
                case .library(let libraryItem):
                    return libraryItem.rawValue.capitalized

                case .source(let id):
                    return viewModel.source(for: id)?.title ?? ""
            }
        }

        private func icon(for item: ImportItem) -> String {
            switch item {
                case .library(let libraryItem):
                    return libraryItem.systemImage

                case .source(let id):
                    return viewModel.source(for: id)?.kind.systemImage ?? "folder"
            }
        }

        private func dragID(for item: ImportItem) -> String {
            switch item {
                case .library(let libraryItem):
                    return libraryItem.rawValue

                case .source(let id):
                    return id.uuidString
            }
        }
    }
}

#Preview {
    ImportsView()
}
