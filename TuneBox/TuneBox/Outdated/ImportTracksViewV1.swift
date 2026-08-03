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

private enum ImportTrackMode {
    case files
    case folder
    case playlist
}

private enum ViewMode {
    case playlists
    case tracks
}

private struct ImportMenuItem {
    let title: String
    let icon: String
    let mode: ImportTrackMode
}

struct ImportedPlaylist: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let fileURL: URL
    let trackURLs: [URL]
}

struct ImportTracksViewV1: View {

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 5) {
            HeaderView(
                editMode: $editMode,
                viewMode: $viewMode,
                importMode: $importMode,
                showsToolbarDeleteConfirmation: $showsToolbarDeleteConfirmation,
                showFileImporter: $showFileImporter,
                importViewModel: importViewModel,
                playerViewModel: playerViewModel
            )

            Group {
                if importViewModel.showsEmptyState {
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
                        isShowingExpandedPlayer: $isShowingExpandedPlayer,
                        showDeletePlaylistDialog: $showDeletePlaylistDialog,
                        showFileImporter: $showFileImporter,
                        showPhotoPicker: $showPhotoPicker,
                        importViewModel: importViewModel,
                        playerViewModel: playerViewModel
                    )
                }
            }
        }
        .onAppear {
            importViewModel.startObservingTracksChanges()
            importViewModel.fetchPlaylists()
        }
        .onDisappear {
            importViewModel.stopObservingTracksChanges()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: allowsMultipleSelection,
            onCompletion: { result in
                switch result {
                    case .success(let urls):
                        switch importMode {
                            case .folder:
                                Task {
                                    await importViewModel.createPlaylist(with: urls)
                                }

                            case .files:
                                switch importViewModel.playlistAction {
                                    case .addTracks(let playlist):
                                        Task {
                                            await importViewModel.addFiles(urls, to: playlist)
                                        }

                                    default:
                                        selectedImportURLs = urls
                                        importViewModel.playlistAction = .create
                                }

                            case .playlist:
                                guard let folderURL = urls.first else {
                                    return
                                }

                                importedPlaylists = importViewModel.loadPlaylists(from: folderURL)
                                showImportPlaylists = true
                        }

                    case .failure(let error):
                        AppLogger.imported.warning("\(error.localizedDescription)")
                }
            }
        )
        .sheet(isPresented: $showImportPlaylists) {
            ImportPlaylistsView(
                showImportPlaylists: $showImportPlaylists,
                viewModel: importViewModel,
                playlists: importedPlaylists
            )
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhoto,
            matching: .images,
        )
        .alert(
            playlistDialogTitle,
            isPresented: Binding(
                get: { showsPlaylistDialog
                },
                set: { isPresented in
                    if !isPresented {
                        importViewModel.playlistAction = nil
                    }
                }
            )
        ) {
            let urls = selectedImportURLs
            TextField("Playlist title", text: $playlistTitle)

            Button("Cancel", role: .cancel) {
                importViewModel.playlistAction = nil
                selectedImportURLs.removeAll()
                playlistTitle = ""
            }

            Button("Save") {
                let title = playlistTitle

                switch importViewModel.playlistAction {
                    case .create:
                        Task {
                            await importViewModel.importFiles(
                                urls,
                                playlistTitle: title
                            )
                        }

                    case .rename(let playlist):
                        importViewModel.renamePlaylist(
                            playlist,
                            newTitle: title
                        )

                    default:
                        break
                }
                importViewModel.playlistAction = nil
                playlistTitle = ""
                selectedImportURLs.removeAll()
            }
        } message: {
            Text("\(playlistDialogMessage)")
        }
    }

    // MARK: - Private. Properties

    private enum Constants {
        static let importFolderTitle = "Import folder"
        static let importPlaylistTitle = "Import playlist"
        static let createPlaylistTitle = "Create playlist"
        static let createPlaylistIcon = "plus"
        static let importPlaylistIcon = "music.note.list"
        static let importFolderIcon = "folder"
        static let flacUTType = UTType(filenameExtension: "flac") ?? .audio

        static let importMenuItems: [ImportMenuItem] = [
            .init(
                title: Constants.createPlaylistTitle,
                icon: createPlaylistIcon,
                mode: .files
            ),
            .init(
                title: Constants.importPlaylistTitle,
                icon: importPlaylistIcon,
                mode: .playlist
            ),
            .init(
                title: Constants.importFolderTitle,
                icon: importFolderIcon,
                mode: .folder
            )
        ]
    }

    @Injected private var importViewModel: ImportManagingV1
    @Injected private var playerViewModel: PlayerManaging
    @State private var playlistTitle: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var importedPlaylists: [ImportedPlaylist] = []
    @State private var selectedImportURLs: [URL] = []
    @State private var editMode: EditMode = .inactive
    @State private var importMode: ImportTrackMode = .files
    @State private var isShowingExpandedPlayer = false
    @State private var viewMode: ViewMode = .playlists
    @State private var showImportPlaylists = false
    @State private var showDeletePlaylistDialog = false
    @State private var showsToolbarDeleteConfirmation = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false

    private var allowedContentTypes: [UTType] {
        switch importMode {
            case .folder:
                return [.folder]

            case .files:
                return [.mp3, .wav, Constants.flacUTType]

            case .playlist:
                return [.folder]
        }
    }

    private var allowsMultipleSelection: Bool {
        switch importMode {
            case .files:
                return true

            case .folder, .playlist:
                return false
        }
    }

    private var playlistDialogTitle: String {
        switch importViewModel.playlistAction {
            case .create:
                return "New Playlist"

            case .rename:
                return "Rename Playlist"

            default:
                return ""
        }
    }

    private var playlistDialogMessage: String {
        switch importViewModel.playlistAction {
            case .create:
                return "Enter title for this playlist"

            case .rename:
                return "Enter new title"

            default:
                return ""
        }
    }

    private var showsPlaylistDialog: Bool {
        switch importViewModel.playlistAction {
            case .create, .rename:
                return true

            default:
                return false
        }
    }

    // MARK: - Private. Objects

    private struct HeaderView: View {

        // Properties. Public

        @Environment(\.themeManager) private var theme
        @Binding var editMode: EditMode
        @Binding var viewMode: ViewMode
        @Binding var importMode: ImportTrackMode
        @Binding var showsToolbarDeleteConfirmation: Bool
        @Binding var showFileImporter: Bool

        let importViewModel: ImportManagingV1
        let playerViewModel: PlayerManaging

        // MARK: - Body

        var body: some View {
            HStack {
                if viewMode == .tracks {
                    Button {
                        viewMode = .playlists
                        playerViewModel.resetPlayback()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }

                Spacer()

                if importViewModel.playlists.isNotEmpty,
                   viewMode == .playlists {
                    Menu {
                        ForEach(Constants.importMenuItems, id: \.title) { item in
                            Button {
                                importMode = item.mode
                                showFileImporter = true
                            } label: {
                                Label(
                                    item.title,
                                    systemImage: item.icon
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30, weight: .medium))
                            .opacity(showFileImporter ? 0.5 : 1)
                            .disabled(showFileImporter)
                    }
                }

                if viewMode == .tracks {
                    HStack(spacing: 10) {
                        Button(
                            action: {
                                if case .deleteTracks(let playlist) = importViewModel.playlistAction {
                                    if playlist.tracks.count == importViewModel.selectedTracks.count {
                                        showsToolbarDeleteConfirmation = true
                                    } else {
                                        Task {
                                            await importViewModel.deleteSelectedTracks(from: playlist)
                                        }
                                    }
                                }
                            }, label: {
                                Label("Delete", systemImage: "trash")
                                    .foregroundStyle(Color(.systemRed))
                            }
                        )
                        .disabled(importViewModel.selectedTracks.isEmpty)
                        .opacity(importViewModel.selectedTracks.isEmpty ? 0 : 1)
                        .confirmationDialog(
                            "Delete tracks?",
                            isPresented: $showsToolbarDeleteConfirmation
                        ) {
                            Button("Delete", role: .destructive) {
                                if case .deleteTracks(let playlist) = importViewModel.playlistAction {
                                    Task {
                                        await importViewModel.deleteSelectedTracks(from: playlist)
                                        importViewModel.deletePlaylist(playlist)
                                        importViewModel.playlistAction = nil
                                        showsToolbarDeleteConfirmation = false
                                        viewMode = .playlists
                                    }
                                }
                            }

                            Button("Cancel", role: .cancel) {
                                showsToolbarDeleteConfirmation = false
                            }
                        } message: {
                            Text("Are you sure you want to delete all tracks?\nThe playlist will also be deleted")
                        }
                    }

                    Button {
                        editMode = editMode == .active ? .inactive : .active
                        playerViewModel.resetPlayback()
                    } label: {
                        Text(editMode == .active ? "Normal" : "Edit")
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
        @Binding var isShowingExpandedPlayer: Bool
        @Binding var showDeletePlaylistDialog: Bool
        @Binding var showFileImporter: Bool
        @Binding var showPhotoPicker: Bool

        let importViewModel: ImportManagingV1
        let playerViewModel: PlayerManaging

        // MARK: - Body

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    PlaylistsGridView(
                        importMode: $importMode,
                        viewMode: $viewMode,
                        selectedPhoto: $selectedPhoto,
                        showDeletePlaylistDialog: $showDeletePlaylistDialog,
                        showFileImporter: $showFileImporter,
                        showPhotoPicker: $showPhotoPicker,
                        importViewModel: importViewModel
                    )
                    .offset(x: viewMode == .playlists ? 0 : -geometry.size.width)

                    TracksView(
                        editMode: $editMode,
                        viewMode: $viewMode,
                        showDeletePlaylistDialog: $showDeletePlaylistDialog,
                        isShowingExpandedPlayer: $isShowingExpandedPlayer,
                        importViewModel: importViewModel
                    )
                    .offset(x: viewMode == .tracks ? 0 : geometry.size.width)
                }
                .sheet(isPresented: $isShowingExpandedPlayer) {
                    Text("Expanded player")
                }
                .animation(.easeInOut(duration: 0.25), value: viewMode)
            }
        }
    }

    private struct PlaylistsGridView: View {

        // MARK: - Properties. Public

        @Binding var importMode: ImportTrackMode
        @Binding var viewMode: ViewMode
        @Binding var selectedPhoto: PhotosPickerItem?
        @Binding var showDeletePlaylistDialog: Bool
        @Binding var showFileImporter: Bool
        @Binding var showPhotoPicker: Bool

        let importViewModel: ImportManagingV1

        var body: some View {
            GeometryReader { geometry in
                let columns = Array(
                    repeating: GridItem(.flexible(), spacing: Layout.gridSpacing),
                    count: geometry.size.width > GlobalConstants.Screen.regularWidth ? 3 : 2
                )

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
                        ForEach(importViewModel.playlists) { playlist in
                            PlaylistCellV1(
                                playlist: playlist,
                                onCellTap: {
                                    importViewModel.playlistAction = .deleteTracks(playlist)
                                    viewMode = .tracks
                                },
                                onPlayBtnTap: {
                                },
                                onChangeCoverBtnTap: {
                                    showPhotoPicker = true
                                    importViewModel.playlistAction = .changeCover(playlist)
                                },
                                onAddTracksBtnTap: {
                                    importViewModel.playlistAction = .addTracks(playlist)
                                    showFileImporter = true
                                    importMode = .files
                                },
                                onRenamePlaylistBtnTap: {
                                    importViewModel.playlistAction = .rename(playlist)
                                },
                                onDeletePlaylistBtnTap: {
                                    importViewModel.playlistAction = .deletePlaylist(playlist)
                                }
                            )
                            .confirmationDialog(
                                "Delete Playlist?",
                                isPresented: Binding(
                                    get: {
                                        if case .deletePlaylist(let selected) = importViewModel.playlistAction {
                                            return selected.id == playlist.id
                                        }
                                        return false
                                    },
                                    set: { isPresented in
                                        if !isPresented {
                                            importViewModel.playlistAction = nil
                                        }
                                    }
                                )
                            ) {
                                Button("Delete", role: .destructive) {
                                    if case .deletePlaylist(let playlist) = importViewModel.playlistAction {
                                        Task {
                                            for track in playlist.tracks {
                                                await importViewModel.removeTrack(track: track, from: playlist)
                                            }
                                            importViewModel.deletePlaylist(playlist)
                                        }
                                        importViewModel.playlistAction = nil
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

                                    if case .changeCover(let playlist) = importViewModel.playlistAction {
                                        importViewModel.setCoverImage(data, playlist: playlist)
                                    }
                                    selectedPhoto = nil
                                    importViewModel.playlistAction = nil
                                }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 5)
                    .padding(.horizontal)
                }
                .contentMargins(.bottom, 20)
            }
        }

        // MARK: - Private. Properties

        private enum Layout {
            static let compactColumnCount = 2
            static let regularColumnCount = 3
            static let gridSpacing: CGFloat = 16
        }
    }

    private struct TracksView: View {
        @Injected private var playerViewModel: PlayerManaging
        @Binding var editMode: EditMode
        @Binding var viewMode: ViewMode
        @Binding var showDeletePlaylistDialog: Bool
        @Binding var isShowingExpandedPlayer: Bool

        let importViewModel: ImportManagingV1

        var body: some View {
            switch importViewModel.playlistAction {
                case .deleteTracks(let playlist), .deletePlaylist(let playlist):
                    ZStack(alignment: .bottom) {
                        ScrollView(showsIndicators: false) {
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
                                            isSelected: importViewModel.selectedTracks.contains(track),
                                            showsMenu: true,
                                            editMode: editMode,
                                            onDeleteFromPlaylistTap: {
                                                if playlist.tracks.count == 1 {
                                                    showDeletePlaylistDialog = true
                                                } else {
                                                    Task {
                                                        await importViewModel.removeTrack(track: track, from: playlist)
                                                    }
                                                }
                                            },
                                            onCellTap: {
                                                if editMode == .active {
                                                    importViewModel.toogleSelection(for: track)
                                                } else {
                                                    playerViewModel.resetPlayback()
                                                    importViewModel.selectedTrack = track
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
                                                await importViewModel.removeTrack(track: track, from: playlist)
                                            }
                                            importViewModel.deletePlaylist(playlist)
                                            importViewModel.playlistAction = nil
                                            showDeletePlaylistDialog = false
                                            viewMode = .playlists
                                        }
                                    }

                                    Button("Cancel", role: .cancel) {
                                        showDeletePlaylistDialog = false
                                    }
                                } message: {
                                    Text("This is the last track. The playlist will also be deleted.")
                                }
                            }
                            .padding(.top, 20)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .contentMargins(.bottom, 20)
                        }

                        CompactPlayerView(
                            track: importViewModel.selectedTrack,
                            isPlaying: importViewModel.selectedTrack.map { playerViewModel.isPlaying($0) } ?? false,
                            progress: playerViewModel.progress,
                            onRewindTap: {
                                AudioService.shared.seek(by: -10)
                            }, onPlayPauseTap: {
//                                guard let track = importViewModel.selectedTrack else { return }
//                                playerViewModel.handlePlayAction(for: track)
                            }, onForwardTap: {
                                AudioService.shared.seek(by: 10)
                            },
                            onProgressTap: {
                                isShowingExpandedPlayer = true
                            }
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }

                default:
                    EmptyView()
            }
        }
    }

    private struct ImportPlaylistsView: View {
        @Binding var showImportPlaylists: Bool

        let viewModel: ImportManagingV1
        let playlists: [ImportedPlaylist]

        var body: some View {
            VStack(spacing: 10) {
                HStack {
                    Spacer()

                    Button(
                        action: {
                            Task {
                                await viewModel.createSelectedPlaylists()
                                showImportPlaylists = false
                            }
                        }, label: {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.blue.opacity(0.6))
                                .frame(width: 80, height: 40)
                                .overlay {
                                    Text("Import")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 20, weight: .medium))
                                }
                        }
                    )
                    .disabled(viewModel.selectedPlaylists.isEmpty)
                    .opacity(viewModel.selectedPlaylists.isEmpty ? 0.5 : 1)
                }

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(playlists) { playlist in
                            ImportedPlaylistCell(
                                playlist: playlist,
                                isSelected: viewModel.selectedPlaylists.contains(playlist),
                                onCellTap: {
                                    viewModel.toogleSelection(for: playlist)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
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
                    ForEach(Constants.importMenuItems, id: \.title) { item in
                        Button(
                            action: {
                                importMode = item.mode
                                showFileImporter = true
                            }, label: {
                                Label(
                                    item.title,
                                    systemImage: item.icon
                                )
                            }
                        )
                    }
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
