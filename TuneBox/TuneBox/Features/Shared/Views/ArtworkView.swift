//
//  ArtworkView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import SDWebImageSwiftUI

struct ArtworkView: View {

    // MARK: - Properties. Public

    let artworkPath: String?
    let size: CGFloat
    let cornerRadius: CGFloat

    // MARK: - Main Body

    var body: some View {
        if isRemoteURL(artworkPath),
           let path = artworkPath,
           let url = URL(string: path) {
            WebImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                placeholder
            }
            .frame(size: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else if let path = artworkPath,
           let url = AudioMetadataService.artworkURL(for: path),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(size: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            Image(systemName: "square.stack")
                .font(.system(size: size * 0.4))
                .frame(width: size, height: size)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.gray.opacity(0.2))
                }
        }
    }

    // MARK: - Properties. Private

    private var placeholder: some View {
        Image(systemName: "music.note")
            .resizable()
            .scaledToFit()
            .padding(16)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
    }

    private func isRemoteURL(_ path: String?) -> Bool {
        guard let path else { return false }

        return path.hasPrefix("http://") || path.hasPrefix("https://")
    }
}
