//
//  AlbumСoversView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 11.08.2026.
//

import SwiftUI

struct AlbumСoversView: View {
    let coverPaths: [String]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(coverPaths, id: \.self) { path in
                    CoverCell(
                        coverPath: path,
                        size: 100, cornerRadius: 10
                    )
                }
            }
            .padding(16)
        }
        .navigationTitle("Covers")
        .navigationBarTitleDisplayMode(.inline)
    }
}
