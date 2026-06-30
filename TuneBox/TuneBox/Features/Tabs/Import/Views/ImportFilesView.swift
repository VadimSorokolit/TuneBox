//
//  ImportFilesView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.05.2026.
//

import Resolver
import SwiftUI
import UniformTypeIdentifiers

struct ImportFilesView: View {

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(showImporter: $showImporter)

            Group {
                if viewModel.showsEmptyState {
                    EmptyStateView()
                } else {
                    ContentView(viewModel: viewModel)
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.audio],
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

    @Injected private var viewModel: ImportManaging
    @State private var showImporter = false

    // MARK: - Private. Objects

    private struct HeaderView: View {
        @Environment(\.themeManager) private var theme
        @Binding var showImporter: Bool

        var body: some View {
            HStack {
                Spacer()

                Button(action: {
                    showImporter = true
                }, label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.black)
                        .font(.system(size: 20, weight: .semibold))
                })
                .opacity(showImporter ? 0.5 : 1)
                .disabled(showImporter)
            }
            .padding(.horizontal, 24)
        }
    }

    private struct ContentView: View {
        let viewModel: ImportManaging

        var body: some View {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.importedTracks, id: \.id) { track in
                        TrackCell(track: track, onButtonTap: {})
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.removeImportedItem(by: track.id)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(.top, 5)
            .contentMargins(.bottom, 20)
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
