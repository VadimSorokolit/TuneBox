//
//  ImportFilesView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.05.2026.
//

import Resolver
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

enum ImportMode {
    case files
    case folder
}

struct ImportFilesView: View {

    // MARK: - Main Body

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
                    EmptyStateView(
                        importMode: $importMode,
                        showFileImporter: $showFileImporter,
                        showCreatePlaylistDialog: $showCreatePlaylistDialog
                    )
                } else {
                    ContentView(
                        editMode: $editMode,
                        selectedPhoto: $selectedPhoto,
                        selectedPlaylist: $selectedPlaylist,
                        showPhotoPicker: $showPhotoPicker,
                        viewModel: viewModel
                    )
                }
            }
        }
        .onAppear {
            viewModel.startObservingTracksChanges()
            viewModel.fetchPlaylists()
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
                        switch importMode {
                            case .folder:
                                Task {
                                    await viewModel.addImportItems(from: urls)
                                }

                            case .files:
                                selectedImportURLs = urls
                                showCreatePlaylistDialog = true
                        }
                    case .failure(let error):
                        AppLogger.imported.warning("\(error.localizedDescription)")
                }
            }
        )
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhoto,
            matching: .images,
        )
        .onTapGesture {
            selectedPlaylist = nil
        }
        .onChange(of: showCreatePlaylistDialog) { _, dialog in
            if dialog == false {
                newPlaylistTitle = ""
            }
        }
        .alert("New Playlist", isPresented: $showCreatePlaylistDialog) {
            TextField("Playlist title", text: $newPlaylistTitle)

            Button("Cancel", role: .cancel) {
                showCreatePlaylistDialog = false
                selectedImportURLs.removeAll()
            }

            Button("Save") {
                if newPlaylistTitle.trimmingCharacters(in: .whitespacesAndNewlines).isNotEmpty {
                    Task {
                        await viewModel.importFiles(selectedImportURLs, playlistTitle: newPlaylistTitle)
                        showCreatePlaylistDialog = false
                        selectedImportURLs.removeAll()
                    }
                }
            }
        } message: {
            Text("Enter a title for this playlist")
        }
    }

    // MARK: - Private. Properties

    @Injected
    private var viewModel: ImportManaging
    @Injected
    @ObservationIgnored
    private var persistenceService: PersistenceServicing
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPlaylist: PlaylistEntity?
    @State private var selectedImportURLs: [URL] = []
    @State private var newPlaylistTitle: String = ""
    @State private var editMode: EditMode = .inactive
    @State private var importMode: ImportMode = .files
    @State private var showPhotoPicker = false
    @State private var showCreatePlaylistDialog = false
    @State private var showFileImporter = false

    // MARK: - Private. Objects

    private struct HeaderView: View {
        @Environment(\.themeManager) private var theme
        @Binding var editMode: EditMode
        @Binding var importMode: ImportMode
        @Binding var showFileImporter: Bool
        let viewModel: ImportManaging

    // MARK: - Body

        var body: some View {
            HStack {
                if viewModel.playlists.isNotEmpty {
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

                if viewModel.playlists.isNotEmpty {
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
            }
            .padding(.horizontal, 24)
        }
    }

    private struct ContentView: View {
        @Binding var editMode: EditMode
        @Binding var selectedPhoto: PhotosPickerItem?
        @Binding var selectedPlaylist: PlaylistEntity?
        @Binding var showPhotoPicker: Bool
        let viewModel: ImportManaging

        // MARK: - Private. Properties
        private enum Layout {
            static let compactColumnCount = 2
            static let regularColumnCount = 3
            static let gridSpacing: CGFloat = 16
        }

        // MARK: - Main Body
        var body: some View {
            GeometryReader { geometry in
                let columnCount = (geometry.size.width > GlobalConstants.Screen.regularWidth)
                ? Layout.regularColumnCount
                : Layout.compactColumnCount
                let columns = Array(repeating: GridItem(.flexible(), spacing: Layout.gridSpacing), count: columnCount)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
                        ForEach(viewModel.playlists) { playlist in
                            PlaylistCell(
                                playlist: playlist,
                                onPlayBtnTap: {
                                    print("")
                                },
                                onChangeCoverBtnTap: {
                                    showPhotoPicker = true
                                    selectedPlaylist = playlist
                                },
                                onAddTracksBtnTap: {
                                    print("")
                                },
                                onRenamePlaylistBtnTap: {
                                    print("")
                                },
                                onDeletePlaylistBtnTap: {
                                    selectedPlaylist = playlist
                                }
                            )
                            .confirmationDialog(
                                "Delete Playlist?",
                                isPresented: Binding(
                                    get: {
                                        selectedPlaylist?.id == playlist.id
                                    },
                                    set: {
                                        if !$0 { selectedPlaylist = nil }
                                    }
                                ),
                                titleVisibility: .visible
                            ) {
                                Button("Delete", role: .destructive) {
                                    if let playlist = selectedPlaylist {
                                        viewModel.deletePlaylist(playlist)
                                    }

                                    selectedPlaylist = nil
                                }
                            } message: {

                                Text("This action cannot be undone")
                            }

                            .onChange(of: selectedPhoto) { _, item in
                                Task {
                                    guard
                                        let item,
                                        let data = try? await item.loadTransferable(type: Data.self)
                                    else {
                                        return
                                    }

                                    if let playlist = selectedPlaylist {
                                        viewModel.setCoverImage(data, playlist: playlist)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
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

    struct EmptyStateView: View {

        // MARK: - Properties. Public

        @Binding var importMode: ImportMode
        @Binding var showFileImporter: Bool
        @Binding var showCreatePlaylistDialog: Bool

        // MARK: - Body

        var body: some View {
            VStack(spacing: 40) {
                Spacer()

                Menu {
                    Button(
                        action: {
                            showFileImporter = true
                            importMode = .files
                        }, label: {
                            Label("Create new playlist", systemImage: "plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    )

                    Button(
                        action: {
                            showFileImporter = true
                            importMode = .folder
                        }, label: {
                            Label("Import new playlist", systemImage: "doc.text")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    )
                } label: {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundStyle(.black)
                        )
                }

                Text("There are no playlists in your library")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
