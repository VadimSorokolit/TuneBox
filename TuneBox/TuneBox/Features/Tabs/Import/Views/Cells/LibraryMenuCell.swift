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

    let title: String
    let icon: String
    let dragID: String
    let isEditMode: Bool
    let isSelected: Bool
    let showsChevron: Bool
    let onTapGesture: () -> Void
    let onDragStarted: () -> Void
    let onDropEntered: () -> Void
    let onDropEnded: () -> Void

    // MARK: - Main Body

    var body: some View {
        rowContent
            .padding(.top, 15)
            .background(isEditMode && isSelected ? .gray.opacity(0.5) : .clear)
            .onDrag {
                guard isEditMode else {
                    return NSItemProvider()
                }

                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDragStarted()

                return NSItemProvider(object: dragID as NSString)
            } preview: {
                Color.clear
                    .frame(width: 1, height: 1)
            }
            .onDrop(
                of: [UTType.text],
                delegate: ItemReorderDropDelegate(
                    isEditMode: isEditMode,
                    onDropEntered: onDropEntered,
                    onDropEnded: onDropEnded
                )
            )
    }

    // MARK: - Properties. Private

    private var rowContent: some View {
        VStack(spacing: 15) {
            HStack {
                HStack(spacing: 10) {
                    if isEditMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? .blue : .gray)
                            .font(.system(size: 22, weight: .medium))
                    }

                    Image(systemName: icon)
                        .foregroundStyle(.gray)
                        .font(.system(size: 22, weight: .medium))
                        .frame(size: 22)

                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onTapGesture)

                Spacer()

                if isEditMode {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.gray)
                        .font(.system(size: 14, weight: .regular))
                        .padding(15)
                } else if showsChevron {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Private. Objects

    private struct ItemReorderDropDelegate: DropDelegate {

        // MARK: - Properties. Public

        let isEditMode: Bool
        let onDropEntered: () -> Void
        let onDropEnded: () -> Void

        // MARK: - Methods. Public

        func performDrop(info: DropInfo) -> Bool {
            onDropEnded()
            return true
        }

        func dropEntered(info: DropInfo) {
            guard isEditMode else { return }

            withAnimation(.snappy) {
                onDropEntered()
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
        title: "Artists",
        icon: "music.mic",
        dragID: "artists",
        isEditMode: false,
        isSelected: false,
        showsChevron: false,
        onTapGesture: {},
        onDragStarted: {},
        onDropEntered: {},
        onDropEnded: {}
    )
}
