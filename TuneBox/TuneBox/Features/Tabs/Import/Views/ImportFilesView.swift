//
//  ImportFilesView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.05.2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportFilesView: View {

    // MARK: - Main Body

    var body: some View {
        ImportEmptyStateView(onButtonTap: {
            showImporter = true
        })
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.audio],
            allowsMultipleSelection: true,
            onCompletion: { result in
                switch result {
                    case .success(let urls):
                        handle(urls)

                    case .failure(let error):
                        print(error)
                }
            }
        )
    }

    // MARK: - Private. Properties

    @State private var showImporter = false

    // MARK: - Private. Objects

    private struct ImportEmptyStateView: View {
        let onButtonTap: () -> Void

        var body: some View {
            VStack(spacing: 14) {

                Spacer()

                Image(systemName: "folder.badge.plus")
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

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onButtonTap()
                } label: {
                    Text("Import files")
                        .font(.headline)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                .padding(.top, 8)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Private. Methods
    private func handle(_ urls: [URL]) {}
}
