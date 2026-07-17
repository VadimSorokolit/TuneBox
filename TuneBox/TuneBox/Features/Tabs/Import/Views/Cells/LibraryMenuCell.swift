//
//  LibraryMenuCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct LibraryMenuCell: View {

    // MARK: - Properties. Public

    let item: ImportItem
    let isEditMode: Bool
    let isSelected: Bool
    let viewModel: TestManaging
    let onTapGesture: () -> Void

    // MARK: - Body

    var body: some View {
        HStack {
            switch item {
                case .library(let libraryItem):
                    VStack(spacing: 15) {
                        HStack {
                            HStack(spacing: 10) {
                                if isEditMode {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSelected ? .blue : .gray)
                                        .font(.system(size: 22, weight: .medium))
                                }

                                Image(systemName: libraryItem.systemImage)
                                    .foregroundStyle(.gray)
                                    .font(.system(size: 22, weight: .medium))
                                    .frame(width: 22, height: 22)

                                Text(libraryItem.rawValue.capitalized)
                                    .font(.system(size: 18, weight: .regular))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onTapGesture()
                            }

                            Spacer()

                            if isEditMode {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.gray)
                                    .font(.system(size: 14, weight: .regular))
                                    .padding(15)
                                    .contentShape(Rectangle())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 26)

                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                            .padding(.leading, 58)
                            .padding(.trailing, 26)
                    }
                    .padding(.top, 15)
                    .background(isEditMode && isSelected ? .gray.opacity(0.5) : .clear)
                    .onDrag {
                        guard isEditMode else {
                            return NSItemProvider()
                        }

                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.prepare()
                        generator.impactOccurred()

                        viewModel.draggingLibraryItem = libraryItem
                        return NSItemProvider(object: libraryItem.rawValue as NSString)
                    } preview: {
                        Color.clear
                            .frame(width: 1, height: 1)
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: LibraryReorderDropDelegate(
                            target: libraryItem,
                            viewModel: viewModel
                        )
                    )

                case .source(let id):
                    if let source = viewModel.source(for: id) {
                        menuRow(
                            icon: source.kind.systemImage,
                            title: source.title,
                            showsChevron: true
                        )
                    }

                case .addSource(let sourceKind):
                    menuRow(
                        icon: sourceKind.systemImage,
                        title: sourceKind.addTitle,
                        showsChevron: false
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func menuRow(
        icon: String,
        title: String,
        showsChevron: Bool = false
    ) -> some View {
        VStack(spacing: 15) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundStyle(.gray)
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 22, height: 22)

                    Text(title)
                        .font(.system(size: 18, weight: .regular))
                }

                Spacer()

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.gray)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 26)

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.leading, 58)
                .padding(.trailing, 26)
        }
        .padding(.top, 15)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapGesture()
        }
    }
    // MARK: - Private. Objects

    private struct LibraryReorderDropDelegate: DropDelegate {

        // MARK: - Properties. Public

        let target: LibraryItem
        let viewModel: TestManaging

        // MARK: - Methods. Public

        func performDrop(info: DropInfo) -> Bool {
            viewModel.draggingLibraryItem = nil
            return true
        }

        func dropEntered(info: DropInfo) {
            guard viewModel.editSectionModeEnabled else { return }

            withAnimation(.snappy) {
                viewModel.moveLibraryItem(to: target)
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }
    }
}

#Preview {
    LibraryMenuCell(
        item: .library(.artists),
        isEditMode: true,
        isSelected: false,
        viewModel: TestViewModel(),
        onTapGesture: {}
    )
}
