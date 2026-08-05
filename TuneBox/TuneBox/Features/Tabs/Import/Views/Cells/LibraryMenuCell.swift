//
//  LibraryMenuCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI

struct LibraryMenuCell: View {

    // MARK: - Properties. Public

    let title: String
    let icon: String
    let isEditMode: Bool
    let isSelected: Bool
    let showsChevron: Bool
    let sourceStorageSize: String?
    let onTapGesture: () -> Void
    let onDragStarted: () -> Void
    /// Reports finger translation and returns the translation clamped to the section bounds.
    let onDragChanged: (_ translationHeight: CGFloat, _ rowHeight: CGFloat) -> CGFloat
    let onDragEnded: () -> Void

    // MARK: - Main Body

    var body: some View {
        Button {
            guard suppressNextTap.isFalse else {
                suppressNextTap = false
                return
            }
            onTapGesture()
        } label: {
            rowContent
                .padding(.top, 15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isEditMode && isSelected ? Color.gray.opacity(0.5) : Color.clear)
                .transaction { transaction in
                    transaction.animation = nil
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(reorderGesture, isEnabled: isEditMode)
        .offset(y: dragOffsetY)
        .scaleEffect(isDragging ? 1.02 : 1)
        .shadow(
            color: .black.opacity(isDragging ? 0.15 : 0),
            radius: isDragging ? 8 : 0
        )
        .zIndex(isDragging ? 1 : 0)
        .transaction { transaction in
            // While dragging, ignore list reorder animations on this row —
            // otherwise SwiftUI replays the move from the original index.
            if isDragging {
                transaction.animation = nil
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rowHeight = max(geometry.size.height, 1)
                    }
                    .onChange(of: geometry.size.height) { _, newValue in
                        rowHeight = max(newValue, 1)
                    }
                    .onChange(of: geometry.frame(in: .global).minY) { oldValue, newValue in
                        // Keep the dragged row under the finger after a live swap.
                        guard isDragging else { return }
                        reorderCompensation += oldValue - newValue
                    }
            }
        }
    }

    // MARK: - Properties. Private

    @State private var dragTranslation: CGSize = .zero
    @State private var reorderCompensation: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var suppressNextTap: Bool = false
    @State private var rowHeight: CGFloat = 70

    private var dragOffsetY: CGFloat {
        dragTranslation.height + reorderCompensation
    }

    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35, maximumDistance: 12)
            .sequenced(
                before: DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .global
                )
            )
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }

                if isDragging.isFalse {
                    isDragging = true
                    reorderCompensation = 0
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDragStarted()
                }

                let translation = drag?.translation ?? .zero
                let clampedY = onDragChanged(translation.height, rowHeight)
                dragTranslation = CGSize(width: 0, height: clampedY)
            }
            .onEnded { _ in
                let wasDragging = isDragging

                // Cell is already in its final list slot. Clearing the offset
                // with animation would fly it from the gesture start position.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dragTranslation = .zero
                    reorderCompensation = 0
                    isDragging = false
                }

                guard wasDragging else { return }

                // Long-press drag release also triggers Button; skip that tap.
                suppressNextTap = true
                onDragEnded()
            }
    }

    // MARK: - Objects. Private

    private var rowContent: some View {
        VStack(spacing: 15) {
            HStack(spacing: 10) {
                if isEditMode {
                    Image(systemName: isSelected
                          ? "checkmark.circle.fill"
                          : "circle"
                    )
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .font(.system(size: 22, weight: .medium))
                }

                Image(systemName: icon)
                    .foregroundStyle(.gray)
                    .font(.system(size: 22, weight: .medium))
                    .frame(size: 22)

                VStack(spacing: 0) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let sourceStorageSize {
                        Text(sourceStorageSize)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.gray)
                    }
                }

                Spacer()

                if isEditMode {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.gray)
                        .font(.system(size: 14, weight: .regular))
                        .padding(.leading, 15)
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
}

#Preview {
    LibraryMenuCell(
        title: "Artists",
        icon: "music.mic",
        isEditMode: false,
        isSelected: false,
        showsChevron: false,
        sourceStorageSize: nil,
        onTapGesture: {},
        onDragStarted: {},
        onDragChanged: { translation, _ in translation },
        onDragEnded: {}
    )
}
