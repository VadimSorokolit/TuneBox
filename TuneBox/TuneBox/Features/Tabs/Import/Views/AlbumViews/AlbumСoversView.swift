//
//  AlbumСoversView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 11.08.2026.
//

import SwiftUI

struct AlbumСoversView: View {

    // MARK: - Properties. Public

    let coverPaths: [String]

    // MARK: - Main Body

    var body: some View {
        gridContent
            .background(Color.black.opacity(0.0))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { trailingToolbar }
            .animation(.easeInOut(duration: 0.2), value: selectedIndex)
            .fullScreenCover(isPresented: $isPagerPresented) {
                pagerView
            }
    }

    // MARK: - Properties. Private

    @State private var selectedIndex: Int?
    @State private var isPagerPresented = false

    private var navigationTitle: String {
        if let selectedIndex {
            return "\(selectedIndex + 1) of \(coverPaths.count)"
        }
        return "Covers"
    }

    private var gridContent: some View {
        GeometryReader { geo in
            let cellSize = cellSize(for: geo.size.width)

            ScrollView {
                LazyVGrid(
                    columns: gridColumns(cellSize: cellSize),
                    spacing: Constants.gridSpacing
                ) {
                    ForEach(Array(coverPaths.enumerated()), id: \.offset) { index, path in
                        coverCell(path: path, index: index, cellSize: cellSize)
                    }
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.vertical, Constants.gridSpacing)
            }
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if selectedIndex != nil {
                Button(action: {
                    applySelectedCover()
                }, label: {
                    Text("Apply")
                        .foregroundStyle(Color(.label))
                        .font(.body.weight(.semibold))
                })
            }
        }
    }

    private var pagerView: some View {
        CoverPagerView(
            coverPaths: coverPaths,
            initialIndex: selectedIndex ?? 0,
            onAppleBtn: handlePagerImage
        )
    }

    private enum Constants {
        static let columnsCount = 3
        static let gridSpacing: CGFloat = 2
        static let horizontalPadding: CGFloat = 2
        static let cellCornerRadius: CGFloat = 0
    }

    // MARK: - Private. Methods

    private func coverCell(path: String, index: Int, cellSize: CGFloat) -> some View {
        CoverCell(
            coverPath: path,
            size: cellSize,
            cornerRadius: Constants.cellCornerRadius,
            isSelected: selectedIndex == index,
            onTap: {
                toggleSelection(at: index)
            },
            onLongPress: {
                openPager(at: index)
            }
        )
    }

    private func cellSize(for width: CGFloat) -> CGFloat {
        let availableWidth = width - Constants.horizontalPadding * 2
        let spacingTotal = Constants.gridSpacing * CGFloat(Constants.columnsCount - 1)

        return floor((availableWidth - spacingTotal) / CGFloat(Constants.columnsCount))
    }

    private func gridColumns(cellSize: CGFloat) -> [GridItem] {
        Array(
            repeating: GridItem(.fixed(cellSize), spacing: Constants.gridSpacing),
            count: Constants.columnsCount
        )
    }

    private func toggleSelection(at index: Int) {
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedIndex = selectedIndex == index ? nil : index
        }
    }

    private func openPager(at index: Int) {
        selectedIndex = index
        isPagerPresented = true
    }

    private func handlePagerImage(_ index: Int) {
        selectedIndex = index
        isPagerPresented = false
    }

    private func applySelectedCover() {
        guard let selectedIndex, coverPaths.indices.contains(selectedIndex) else { return }
        let path = coverPaths[selectedIndex]
        isPagerPresented = false
        _ = path
    }
}
