//
//  ImportFilesView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.05.2026.
//

import Resolver
import SwiftUI
import UniformTypeIdentifiers

enum ImportMode {
    case files
    case folder
}

struct ImportFilesView: View {

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                editMode: $editMode,
                importMode: $importMode,
                showFileImporter: $showFileImporter,
                viewModel: viewModel
            )

            Group {
                if viewModel.showsEmptyState {
                    EmptyStateView()
                } else {
                    ContentView(
                        editMode: $editMode,
                        viewModel: viewModel
                    )
                }
            }
        }
        .onAppear {
            viewModel.startObservingTracksChanges()
        }
        .onDisappear {
            viewModel.stopObservingTracksChanges()
        }
        .task {
//            await viewModel.load()
//            viewModel.loadPlaylists()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: importMode == .folder
                ? [UTType.folder]
                : [UTType.audio],
            allowsMultipleSelection: true,
            onCompletion: { result in
                switch result {
                    case .success(let urls):
                        Task { await viewModel.addImportItems(from: urls) }
                    case .failure(let error):
                        AppLogger.imported.warning("\(error.localizedDescription)")
                }
            }
        )
    }

    // MARK: - Private. Properties

    @Injected
    private var viewModel: ImportManaging
    @Injected
    @ObservationIgnored
    private var persistenceService: PersistenceServicing
    @State private var editMode: EditMode = .inactive
    @State private var showFileImporter = false
    @State private var importMode: ImportMode = .files

    // MARK: - Private. Objects

    private struct HeaderView: View {
        @Environment(\.themeManager) private var theme
        @Binding var editMode: EditMode
        @Binding var importMode: ImportMode
        @Binding var showFileImporter: Bool
        let viewModel: ImportManaging

        var body: some View {
            HStack {
                if viewModel.sections
                    .flatMap({ $0.tracks})
                    .isNotEmpty {

                    Button(
                        action: {
                            editMode = editMode == .active ? .inactive : .active
                        }, label: {
                            Text(editMode == .active
                                 ? "Normal"
                                 : "Edit"
                            )
                        }
                    )
                }

                Spacer()

                if editMode == .inactive {
                    Menu(
                        content: {
                            Button(
                                action: {
                                    showFileImporter = true
                                    importMode = .files
                                }, label: {
                                    Label("Import files", systemImage: "music.note")
                                }
                            )

                            Button(
                                action: {
                                    showFileImporter = true
                                    importMode = .folder
                                }, label: {
                                    Label("Import folder", systemImage: "folder.badge.plus")
                                }
                            )
                        },
                        label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    )
                    .opacity(showFileImporter ? 0.5 : 1)
                    .disabled(showFileImporter)
                } else {
                    Button(
                        action: {
                            Task {
                                await viewModel.deleteSelectedTracks()
                            }
                        }, label: {
                            Label("Delete", systemImage: "trash")
                                .foregroundStyle(Color(.systemRed))
                        }
                    )
                    .disabled(viewModel.selectedTrackIDs.isEmpty)
                    .opacity(viewModel.selectedTrackIDs.isEmpty ? 0 : 1)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private struct ContentView: View {
        @Binding var editMode: EditMode
        let viewModel: ImportManaging
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]

        var body: some View {
            ScrollView(showsIndicators: false) {
                if viewModel.playlists.count == 1,
                   let playlist = viewModel.playlists.first {
                    HStack {
                        PlaylistCell(model: playlist)
                            .frame(width: 140)

                        Spacer()
                    }
                    .padding(.horizontal)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.playlists) { playlist in
                            PlaylistCell(model: playlist)
                        }
                    }
                    .padding(.horizontal)
                }
//                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
//                    ForEach(
//                        viewModel.sections,
//                        content: { section in
//                            switch section.type {
//                                case .imported:
//                                    importedTracksSection(section: section)
//
//                                default:
//                                    EmptyView()
//                            }
//                        }
//                    )
//                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 5)
            .contentMargins(.bottom, 20)
        }

        @ViewBuilder
        private func importedTracksSection(section: TracksSection) -> some View {
            if section.tracks.isNotEmpty {
                Section(
                    content: {
                        LazyVStack(spacing: 4) {
                            ForEach(
                                section.tracks,
                                content: { track in
                                    TrackCell(
                                        track: track,
                                        isSelected: viewModel.selectedTrackIDs.contains(track.id),
                                        editMode: editMode,
                                        onButtonTap: {
                                            if editMode == .active {
                                                viewModel.toggleSelection(for: track.id)
                                            } else {
                                                Task {
                                                    await viewModel.removeImportedItem(by: track.id)
                                                }
                                            }
                                        },
                                        onCellTap: {
                                            if editMode == .active {
                                                viewModel.toggleSelection(for: track.id)
                                            }
                                        }
                                    )
                                }
                            )
                        }
                    },
                    header: {
                        sectionTracksTitle(section.title)
                    }
                )
            }
        }
    }

    private struct EmptyStateView: View {
        var body: some View {
            VStack(spacing: 14) {
                Spacer()

                Image(systemName: "folder")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)

                Text("No files yet")
                    .font(.title3.weight(.semibold))

                Text("Import audio files to start building your library")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
