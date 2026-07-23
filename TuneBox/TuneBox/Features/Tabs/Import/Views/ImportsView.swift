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
                    Button(action: {
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
                        Button(action: {
                                isFileImporterPresented = true
                            }, label: {
                                Label("Add Folder", systemImage: "plus")
                            }
                        )

                        Button(action: {
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
            if viewModel.hasVisibleItems || viewModel.isEditSectionModeEnabled {
                ScrollView {
                    LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                        ForEach(viewModel.sections) { section in
                            if section.items.isNotEmpty {
                                Section {
                                    VStack(spacing: 0) {
                                        ForEach(section.items, id: \.self) { item in
                                            menuCell(for: item, in: section)
                                        }
                                    }
                                    .animation(
                                        .easeInOut(duration: 0.6),
                                        value: section.items
                                    )
                                } header: {
                                    sectionTracksTitle(
                                        section.kind.rawValue.capitalized,
                                        font: .system(size: 14, weight: .bold),
                                        foregroundStyle: .gray
                                    )
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

        // MARK: - Private. Properties

        @State private var dragStartIndex: Int?
        @State private var dragSectionKind: ImportSection?

        // MARK: - Private. Methods

        private func menuCell(for item: ImportItem, in section: ImportSectionModel) -> some View {
            LibraryMenuCell(
                title: title(for: item),
                icon: icon(for: item),
                isEditMode: viewModel.isEditSectionModeEnabled,
                isSelected: viewModel.isItemSelected(item),
                showsChevron: showsChevron(for: item),
                onTapGesture: {
                    handleTap(for: item)
                },
                onDragStarted: {
                    viewModel.draggingItem = item
                    dragSectionKind = section.kind
                    dragStartIndex = currentItems(for: section.kind).firstIndex(of: item)
                },
                onDragChanged: { translationHeight, rowHeight in
                    swapIfNeeded(
                        dragging: item,
                        translationHeight: translationHeight,
                        rowHeight: rowHeight
                    )
                },
                onDragEnded: {
                    viewModel.draggingItem = nil
                    dragStartIndex = nil
                    dragSectionKind = nil
                }
            )
        }

        private func swapIfNeeded(
            dragging: ImportItem,
            translationHeight: CGFloat,
            rowHeight: CGFloat
        ) {
            guard viewModel.draggingItem == dragging else { return }
            guard
                let sectionKind = dragSectionKind,
                let startIndex = dragStartIndex
            else {
                return
            }

            let items = currentItems(for: sectionKind)
            guard items.isNotEmpty else { return }

            // Swap after dragging more than half of one row height.
            let safeRowHeight = max(rowHeight, 1)
            let indexDelta = Int((translationHeight / safeRowHeight).rounded())
            let targetIndex = min(
                max(startIndex + indexDelta, items.startIndex),
                items.index(before: items.endIndex)
            )

            guard let currentIndex = items.firstIndex(of: dragging) else { return }
            guard targetIndex != currentIndex else { return }

            withAnimation(.easeInOut(duration: 0.45)) {
                viewModel.moveItem(to: items[targetIndex])
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }

        private func currentItems(for kind: ImportSection) -> [ImportItem] {
            viewModel.sections.first { $0.kind == kind }?.items ?? []
        }

        private func handleTap(for item: ImportItem) {
            if viewModel.isEditSectionModeEnabled {
                viewModel.toggleItem(item)
                return
            }

            switch item {
                case .library(.albums):
                    coordinator.push(.albums)

                case .library(.artists):
                    coordinator.push(.artists)

                case .library(.tracks):
                    coordinator.push(.tracks())

                case .library(.playlists):
                    coordinator.push(.playlists)

                case .source(let id):
                    Task {
                        guard let source = viewModel.source(for: id) else { return }

                        switch source.kind {
                            case .api:
                                coordinator.push(.tracks(onlyAPI: true))

                            case .local, .sync:
                                if await viewModel.fetchfolderItems(
                                    sourceID: id,
                                    path: nil
                                ) != nil {
                                    coordinator.push(.sourceFolder(sourceID: id, path: nil))
                                }
                        }
                    }
            }
        }

        private func showsChevron(for item: ImportItem) -> Bool {
            if case .source = item, viewModel.isEditSectionModeEnabled.isFalse {
                return true
            }
            return false
        }

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
    }
}

#Preview {
    ImportsView()
}
