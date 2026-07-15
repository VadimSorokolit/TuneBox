//
//  ArtworkView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI

struct ArtworkView: View {

    // MARK: - Properties. Public

    let artworkPath: String?
    let size: CGFloat
    let cornerRadius: CGFloat

    // MARK: - Main Body

    var body: some View {
        if let path = artworkPath,
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
}
