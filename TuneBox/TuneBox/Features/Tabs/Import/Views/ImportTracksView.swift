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

enum ImportTrackMode {
    case files
    case folder
}

enum ViewMode {
    case importing
    case removing
}

struct ImportTracksView: View {

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 5) {
            HeaderView(
                editMode: $editMode,
                viewMode: $viewMode,
                importMode: $importMode,
                showFileImporter: $showFileImporter,
                viewModel: viewModel
            )

            Group {
                if viewModel.showsEmptyState {
                    EmptyStateView(
                        importMode: $importMode,
                        showFileImporter: $showFileImporter
                    )
                } else {
                    ContentView(
                        editMode: $editMode,
                        viewMode: $viewMode,
                        importMode: $importMode,
                        selectedPhoto: $selectedPhoto,
                        showFileImporter: $showFileImporter,
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
                                    await viewModel.createPlaylist(with: urls)
                                }

                            case .files:
                                switch viewModel.playlistAction {
                                    case .addTracks(let playlist):
                                        Task {
                                            await viewModel.addFiles(urls, to: playlist)
                                        }

                                    default:
                                        selectedImportURLs = urls
                                        viewModel.playlistAction = .create
                                }
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
        .alert(
            playlistDialogTitle,
            isPresented: Binding(
                get: { showsPlaylistDialog },
                set: { isPresented in
                    if !isPresented {
                        viewModel.playlistAction = nil
                    }
                }
            )
        ) {
            let urls = selectedImportURLs
            TextField("Playlist title", text: $playlistTitle)

            Button("Cancel", role: .cancel) {
                viewModel.playlistAction = nil
                selectedImportURLs.removeAll()
                playlistTitle = ""
            }

            Button("Save") {
                let title = playlistTitle

                switch viewModel.playlistAction {
                    case .create:
                        Task {
                            await viewModel.importFiles(
                                urls,
                                playlistTitle: title
                            )
                        }

                    case .rename(let playlist):
                        viewModel.renamePlaylist(
                            playlist,
                            newTitle: title
                        )

                    default:
                        break
                }
                viewModel.playlistAction = nil
                playlistTitle = ""
                selectedImportURLs.removeAll()
            }
        } message: {
            Text("\(playlistDialogMessage)")
        }
    }

    // MARK: - Private. Properties

    @Injected
    private var viewModel: ImportManaging
    @Injected
    @ObservationIgnored
    private var persistenceService: PersistenceServicing
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImportURLs: [URL] = []
    @State private var playlistTitle: String = ""
    @State private var editMode: EditMode = .inactive
    @State private var importMode: ImportTrackMode = .files
    @State private var viewMode: ViewMode = .importing
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false

    private var playlistDialogTitle: String {
        switch viewModel.playlistAction {
            case .create:
                return "New Playlist"

            case .rename:
                return "Rename Playlist"

            default:
                return ""
        }
    }

    private var playlistDialogMessage: String {
        switch viewModel.playlistAction {
            case .create:
                return "Enter title for this playlist"

            case .rename:
                return "Enter new title"

            default:
                return ""
        }
    }

    private var showsPlaylistDialog: Bool {
        switch viewModel.playlistAction {
            case .create, .rename:
                return true

            default:
                return false
        }
    }

    // MARK: - Private. Objects

    private struct HeaderView: View {
        @Environment(\.themeManager) private var theme
        @Binding var editMode: EditMode
        @Binding var viewMode: ViewMode
        @Binding var importMode: ImportTrackMode
        @Binding var showFileImporter: Bool
        let viewModel: ImportManaging

        // MARK: - Body

        var body: some View {
            HStack {
                if viewMode == .removing {
                    Button {
                        viewMode = .importing
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }

                } else if viewModel.playlists.isNotEmpty {
                    if case .deleteTracks = viewModel.playlistAction {
//                        Button {
//                            editMode = editMode == .active ? .inactive : .active
//                        } label: {
//                            Text(editMode == .active ? "Normal" : "Edit")
//                        }
                    }
                }

                Spacer()

                if viewModel.playlists.isNotEmpty,
                   viewMode == .importing {
                    if editMode == .inactive {
                        Menu(
                            content: {
                                Button(
                                    action: {
                                        showFileImporter = true
                                        importMode = .files
                                    }, label: {
                                        Label("Create new playlist", systemImage: "plus")
                                    }
                                )

                                Button(
                                    action: {
                                        showFileImporter = true
                                        importMode = .folder
                                    }, label: {
                                        Label("Import new playlist", systemImage: "doc.text")
                                    }
                                )
                            },
                            label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 30, weight: .medium))
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

        // Properties. Public

        @Binding var editMode: EditMode
        @Binding var viewMode: ViewMode
        @Binding var importMode: ImportTrackMode
        @Binding var selectedPhoto: PhotosPickerItem?
        @Binding var showFileImporter: Bool
        @Binding var showPhotoPicker: Bool

        let viewModel: ImportManaging

        // MARK: - Body

        var body: some View {
            ScrollView(showsIndicators: false) {
                ZStack {
                    PlaylistsGridView(
                        importMode: $importMode,
                        viewMode: $viewMode,
                        selectedPhoto: $selectedPhoto,
                        showFileImporter: $showFileImporter,
                        showPhotoPicker: $showPhotoPicker,
                        viewModel: viewModel
                    )
                    .offset(x: viewMode == .importing ? 0 : -UIScreen.main.bounds.width)

                    RemoveTracksView(
                        editMode: $editMode,
                        viewMode: $viewMode,
                        viewModel: viewModel
                    )
                    .offset(x: viewMode == .removing ? 0 : UIScreen.main.bounds.width)
                }
            }
            .contentMargins(.bottom, 20)
            .animation(.easeInOut(duration: 0.25), value: viewMode)
        }
    }

    private struct PlaylistsGridView: View {

        // MARK: - Properties. Public

        @Binding var importMode: ImportTrackMode
        @Binding var viewMode: ViewMode
        @Binding var selectedPhoto: PhotosPickerItem?
        @Binding var showFileImporter: Bool
        @Binding var showPhotoPicker: Bool

        let viewModel: ImportManaging

        var body: some View {
            GeometryReader { geometry in
                let columnCount = (geometry.size.width > GlobalConstants.Screen.regularWidth)
                ? Layout.regularColumnCount
                : Layout.compactColumnCount
                let columns = Array(repeating: GridItem(.flexible(), spacing: Layout.gridSpacing), count: columnCount)

                LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
                    ForEach(viewModel.playlists) { playlist in
                        PlaylistCell(
                            playlist: playlist,
                            onCellTap: {
                                viewModel.playlistAction = .deleteTracks(playlist)
                                viewMode = .removing
                            },
                            onPlayBtnTap: {
                                print("")
                            },
                            onChangeCoverBtnTap: {
                                showPhotoPicker = true
                                viewModel.playlistAction = .changeCover(playlist)
                            },
                            onAddTracksBtnTap: {
                                viewModel.playlistAction = .addTracks(playlist)
                                showFileImporter = true
                                importMode = .files
                            },
                            onRenamePlaylistBtnTap: {
                                viewModel.playlistAction = .rename(playlist)
                            },
                            onDeletePlaylistBtnTap: {
                                viewModel.playlistAction = .deletePlaylist(playlist)
                            }
                        )
                        .confirmationDialog(
                            "Delete Playlist?",
                            isPresented: Binding(
                                get: {
                                    if case .deletePlaylist(let selected) = viewModel.playlistAction {
                                        return selected.id == playlist.id
                                    }
                                    return false
                                },
                                set: { isPresented in
                                    if !isPresented {
                                        viewModel.playlistAction = nil
                                    }
                                }
                            )
                        ) {
                            Button("Delete", role: .destructive) {
                                if case .deletePlaylist(let playlist) = viewModel.playlistAction {
                                    Task {
                                        for track in playlist.tracks {
                                            await viewModel.removeTrack(track: track, from: playlist)
                                        }
                                        viewModel.deletePlaylist(playlist)
                                    }
                                    viewModel.playlistAction = nil
                                }
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

                                if case .changeCover(let playlist) = viewModel.playlistAction {
                                    viewModel.setCoverImage(data, playlist: playlist)
                                }

                                viewModel.playlistAction = nil
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 5)
            .contentMargins(.bottom, 20)
        }

        // MARK: - Private. Properties

        private enum Layout {
            static let compactColumnCount = 2
            static let regularColumnCount = 3
            static let gridSpacing: CGFloat = 16
        }
    }

    private struct RemoveTracksView: View {
        @Binding var editMode: EditMode
        @State private var showDeletePlaylistDialog = false
        @Binding var viewMode: ViewMode
        let viewModel: ImportManaging

        var body: some View {
            switch viewModel.playlistAction {
                case .deleteTracks(let playlist), .deletePlaylist(let playlist):
                    VStack(spacing: 10) {
                        Group {
                            if let data = playlist.coverImageData,
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "music.note")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.secondary)
                                    .padding(40)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(
                            playlist.coverImageData == nil
                            ? .brown
                            : .clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        LazyVStack(spacing: 4) {
                            ForEach(playlist.tracks) { track in
                                TrackCell(
                                    track: track,
                                    isSelected: viewModel.selectedTrackIDs.contains(track.id),
                                    editMode: editMode,
                                    onButtonTap: {
                                        if playlist.tracks.count == 1 {
                                            showDeletePlaylistDialog = true
                                        } else {
                                            Task {
                                                await viewModel.removeTrack(track: track, from: playlist)
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
                        }
                        .confirmationDialog(
                            "Delete track?",
                            isPresented: $showDeletePlaylistDialog
                        ) {
                            Button("Delete", role: .destructive) {
                                Task {
                                    if let track = playlist.tracks.last {
                                        await viewModel.removeTrack(track: track, from: playlist)
                                    }
                                    viewModel.deletePlaylist(playlist)
                                    viewModel.playlistAction = nil
                                    showDeletePlaylistDialog = false
                                    viewMode = .importing
                                }
                            }

                            Button("Cancel", role: .cancel) {
                                showDeletePlaylistDialog = false
                            }
                        } message: {
                            Text("This is the last track. The playlist will also be deleted.")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                default:
                    EmptyView()
            }
        }
    }

    private struct EmptyStateView: View {

        // MARK: - Properties. Public

        @Binding var importMode: ImportTrackMode
        @Binding var showFileImporter: Bool

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
