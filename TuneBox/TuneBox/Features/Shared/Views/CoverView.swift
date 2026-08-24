//
//  CoverView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import SDWebImageSwiftUI

struct CoverView: View {

    // MARK: - Properties. Public

    let coverPath: String?
    let size: CGFloat
    let cornerRadius: CGFloat
    let placeholderOpacity: Double
    var onTap: (() -> Void)?

    // MARK: - Initializer

    init(
        coverPath: String?,
        size: CGFloat,
        cornerRadius: CGFloat,
        placeholderOpacity: Double = 0.2,
        onTap: (() -> Void)? = nil
    ) {
        self.coverPath = coverPath
        self.size = size
        self.cornerRadius = cornerRadius
        self.placeholderOpacity = placeholderOpacity
        self.onTap = onTap
    }

    // MARK: - Main Body

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        let cover = content
            .frame(size: size)
            .clipShape(shape)
            .contentShape(shape)

        cover
            .onTapGesture {
                onTap?()
            }
    }

    // MARK: - Properties. Private

    @ViewBuilder
    private var content: some View {
        if isRemoteURL(coverPath),
           let path = coverPath,
           let url = URL(string: path) {
            WebImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholder
            }
        } else if let path = coverPath,
                  let url = AudioMetadataService.coverURL(for: path),
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "square.stack")
                .font(.system(size: size * 0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.gray.opacity(placeholderOpacity))
                }
        }
    }

    private var placeholder: some View {
        Image(systemName: "music.note")
            .resizable()
            .scaledToFit()
            .padding(16)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
    }

    // MARK: - Methods. Private

    private func isRemoteURL(_ path: String?) -> Bool {
        guard let path else { return false }

        return path.hasPrefix("http://") || path.hasPrefix("https://")
    }
}
