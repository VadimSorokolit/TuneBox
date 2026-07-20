//
//  SourceView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 17.07.2026.
//

import SwiftUI
import Resolver

struct SourceView: View {

    // MARK: - Properties. Public

    let sourceID: ImportSource.ID
    let path: String?

    // MARK: - Main Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    row(for: item)
                }
            }
        }
        .navigationTitle(path?.components(separatedBy: "/").last ?? viewModel.source(for: sourceID)?.title ?? "Source")
        .padding(.top, 16)
        .task(id: path) {
            guard let items = await viewModel.fetchfolderItems(sourceID: sourceID, path: path) else { return }
            self.items = items
        }
    }

    // MARK: - Properties. Private

    @Environment(AppCoordinator.self) private var coordinator
    @Injected private var viewModel: ImportManaging
    @State private var items: [SourceFolderItem] = []

    // MARK: - Methods. Private

    @ViewBuilder
    private func row(for item: SourceFolderItem) -> some View {
        switch item.kind {
            case .folder:
                sourceRow(
                    icon: "folder",
                    title: item.url.lastPathComponent,
                    showsChevron: true,
                    onTapGesture: {
                        coordinator.push(
                            .sourceFolder(
                                sourceID: sourceID,
                                path: nextPath(item.url.lastPathComponent)
                            )
                        )
                    }
                )

            case .track:
                sourceRow(
                    icon: "music.note",
                    title: item.url.deletingPathExtension().lastPathComponent,
                    onTapGesture: {}
                )

            case .playlist:
                if let playlist = viewModel.playlist(for: item.url) {
                    NewPlaylistCell(
                        playlist: playlist,
                        onTapGesture: {
                            coordinator.push(.playlist(playlist))
                        }
                    )
                }
        }
    }

    private func nextPath(_ folderName: String) -> String {
        guard let path, path.isEmpty == false else {
            return folderName
        }

        return "\(path)/\(folderName)"
    }

    private func openPlaylist(_ url: URL) {
        let title = url.deletingPathExtension().lastPathComponent

        guard let playlist = viewModel.library?.playlists.first(
            where: { $0.title == title }
        ) else {
            return
        }

        coordinator.push(.playlist(playlist))
    }

    private func sourceRow(
        icon: String,
        title: String,
        showsChevron: Bool = false,
        onTapGesture: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 15) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.gray)
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 22, height: 22)

                Text(title)
                    .font(.system(size: 18))
                    .lineLimit(1)

                Spacer()

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.gray)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .padding(.horizontal, 26)

            Rectangle()
                .fill(.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.leading, 58)
                .padding(.trailing, 26)
        }
        .padding(.top, 15)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapGesture)
    }
}
