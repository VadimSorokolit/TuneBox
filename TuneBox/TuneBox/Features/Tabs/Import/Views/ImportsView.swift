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
                importManagingVM: importManagingVM
            )

            if importManagingVM.hasLibrary {
                ContentView(
                    sourceIDToDelete: $sourceIDToDelete,
                    importManagingVM: importManagingVM
                )
            } else {
                EmptyContentView(
                    isFileImporterPresented: $isFileImporterPresented
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.gray.opacity(0.025))
        .bottomContentMargin(
            10,
            0,
            isPlayerVisible: playerVM.isPlayerVisible,
            isTabBarVisible: rootTabsVM.isTabBarVisible
        )
        .onAppear {
            Task {
                importManagingVM.startObservingTracksChanges()
                await importManagingVM.refreshLibrary()
                playerVM.refreshPlaybackNavigationPath(library: importManagingVM.library)
            }
        }
        .onDisappear {
            importManagingVM.stopObservingTracksChanges()
        }
        .task {
            if importManagingVM.hasLibrary.isFalse {
                await importManagingVM.refreshLibrary()
            }
            playerVM.refreshPlaybackNavigationPath(library: importManagingVM.library)
        }
        .onChange(of: importManagingVM.hasLibrary) { _, hasLibrary in
            guard hasLibrary else { return }
            playerVM.refreshPlaybackNavigationPath(library: importManagingVM.library)
        }
        .onChange(of: importManagingVM.error) { _, newValue in
            isErrorPresented = newValue != nil
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.folder],
            onCompletion: { result in
                switch result {
                    case .success(let url):
                        Task {
                            await importManagingVM.importFolder(url)
                        }

                    case .failure(let error):
                        AppLogger.imported.warning("\(error.localizedDescription)")
                }
            }
        )
        .alert("Error", isPresented: $isErrorPresented) {
            Button("OK", role: .cancel) {
                importManagingVM.dismissError()
            }
        } message: {
            Text(importManagingVM.error ?? "")
        }
        .modifier(CentralSpinnerModifier(isVisible: importManagingVM.isLoading))
    }

    // MARK: - Properties. Private

    @Injected private var rootTabsVM: RootTabsManaging
    @Injected private var importManagingVM: ImportManaging
    @Injected private var playerVM: PlayerManaging
    @State private var sourceIDToDelete: ImportSource.ID?
    @State private var isFileImporterPresented: Bool = false
    @State private var isErrorPresented = false

    // MARK: - Objects. Private

    private struct HeaderView: View {

        // MARK: - Properties. Public

        @Binding var isFileImporterPresented: Bool
        let importManagingVM: ImportManaging

        // MARK: - Body

        var body: some View {
            HStack {
                Spacer()

                if importManagingVM.isEditSectionModeEnabled {
                    Button(action: {
                        importManagingVM.finishEditSections()
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
                            importManagingVM.beginEditSections()
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
            importManagingVM.hasLibrary.isFalse
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
        @Binding var sourceIDToDelete: ImportSource.ID?

        let importManagingVM: ImportManaging

        // MARK: - Body

        var body: some View {
            if importManagingVM.hasVisibleItems || importManagingVM.isEditSectionModeEnabled {
                ScrollView {
                    LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                        ForEach(importManagingVM.sections) { section in
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
                                        background: GlobalConstants.AppColor.defaultBackground,
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
                            importManagingVM.beginEditSections()
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

        private func menuCell(
            for item: ImportItem,
            in section: ImportSectionModel
        ) -> some View {
            LibraryMenuCell(
                title: title(for: item),
                icon: icon(for: item),
                isEditMode: importManagingVM.isEditSectionModeEnabled,
                isSelected: importManagingVM.isItemSelected(item),
                showsChevron: showsChevron(for: item),
                sourceStorageSize: importManagingVM.sourceStorageSize(for: item),
                onTapGesture: {
                    handleTap(for: item)
                },
                onDragStarted: {
                    importManagingVM.draggingItem = item
                    dragSectionKind = section.kind
                    dragStartIndex = currentItems(for: section.kind).firstIndex(of: item)
                },
                onDragChanged: { translationHeight, rowHeight in
                    let clampedHeight = clampedTranslation(
                        translationHeight: translationHeight,
                        rowHeight: rowHeight
                    )
                    swapIfNeeded(
                        dragging: item,
                        translationHeight: clampedHeight,
                        rowHeight: rowHeight
                    )
                    return clampedHeight
                },
                onDragEnded: {
                    importManagingVM.draggingItem = nil
                    dragStartIndex = nil
                    dragSectionKind = nil
                }
            )
            .contextMenu {
                if case .source(let id) = item, importManagingVM.isEditSectionModeEnabled.isFalse {
                    Button(role: .destructive) {
                        sourceIDToDelete = id
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .confirmationDialog(
                "Delete Folder?",
                isPresented: Binding(
                    get: {
                        if case .source(let id) = item {
                            return sourceIDToDelete == id
                        }
                        return false
                    },
                    set: { if !$0 { sourceIDToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let id = sourceIDToDelete {
                        Task {
                            await importManagingVM.removeSource(id)
                        }
                    }
                    sourceIDToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    sourceIDToDelete = nil
                }
            } message: {
                Text("This source will be removed from your library, but the original file will remain on your device.")
            }
        }

        private func clampedTranslation(
            translationHeight: CGFloat,
            rowHeight: CGFloat
        ) -> CGFloat {
            guard
                let sectionKind = dragSectionKind,
                let startIndex = dragStartIndex
            else {
                return translationHeight
            }

            let items = currentItems(for: sectionKind)
            guard items.count > 1 else { return 0 }

            let safeRowHeight = max(rowHeight, 1)
            let maxUp = CGFloat(startIndex) * safeRowHeight
            let maxDown = CGFloat(items.count - 1 - startIndex) * safeRowHeight
            return min(max(translationHeight, -maxUp), maxDown)
        }

        private func swapIfNeeded(
            dragging: ImportItem,
            translationHeight: CGFloat,
            rowHeight: CGFloat
        ) {
            guard importManagingVM.draggingItem == dragging else { return }
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
                importManagingVM.moveItem(to: items[targetIndex])
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }

        private func currentItems(for kind: ImportSection) -> [ImportItem] {
            importManagingVM.sections.first { $0.kind == kind }?.items ?? []
        }

        private func handleTap(for item: ImportItem) {
            if importManagingVM.isEditSectionModeEnabled {
                importManagingVM.toggleItem(item)
                return
            }

            switch item {
                case .library(.albums):
                    coordinator.push(.albums)

                case .library(.artists):
                    coordinator.push(.artists)

                case .library(.tracks):
                    coordinator.push(.tracks(.library))

                case .library(.playlists):
                    coordinator.push(.playlists)

                case .source(let id):
                    Task {
                        guard let source = importManagingVM.source(for: id) else { return }

                        switch source.kind {
                            case .api:
                                coordinator.push(.tracks("Downloaded", .downloads))

                            case .local, .sync:
                                if await importManagingVM.fetchfolderItems(
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
            if case .source = item, importManagingVM.isEditSectionModeEnabled.isFalse {
                return true
            }
            return false
        }

        private func title(for item: ImportItem) -> String {
            switch item {
                case .library(let libraryItem):
                    return libraryItem.rawValue.capitalized

                case .source(let id):
                    return importManagingVM.source(for: id)?.title ?? ""
            }
        }

        private func icon(for item: ImportItem) -> String {
            switch item {
                case .library(let libraryItem):
                    return libraryItem.systemImage

                case .source(let id):
                    return importManagingVM.source(for: id)?.kind.systemImage ?? "folder"
            }
        }
    }
}

#Preview {
    ImportsView()
}
