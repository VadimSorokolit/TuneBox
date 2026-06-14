//
//  SegmentedChipControl.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 03.06.2026.
//

import SwiftUI

enum SlideDirection {
    case forward
    case backward
}

struct SegmentedChipControl<T: SegmentedItem & Hashable>: View {
    private enum ScrollBoundary: Hashable {
        case leading
        case trailing
    }

    @Binding var selected: T
    @Binding var direction: SlideDirection

    let items: [T]

    var body: some View {
        var segmentedChipEdgeInset: CGFloat {
            8
        }

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Color.clear
                        .frame(width: segmentedChipEdgeInset)
                        .id(ScrollBoundary.leading)

                    ForEach(items, id: \.self) { item in
                        ChipButton(
                            title: item.title,
                            isSelected: selected == item
                        ) {
                            select(item)
                        }
                        .id(item)
                    }

                    Color.clear
                        .frame(width: segmentedChipEdgeInset)
                        .id(ScrollBoundary.trailing)
                }
            }
            .contentMargins(.zero, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .frame(height: 32)
            .onAppear {
                scrollToSelected(proxy: proxy, animated: false)
            }
            .onChange(of: selected) { _, _ in
                scrollToSelected(proxy: proxy, animated: true)
            }
        }
    }

    private func select(_ item: T) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if let newIndex = items.firstIndex(of: item),
               let oldIndex = items.firstIndex(of: selected) {
                direction = (newIndex > oldIndex)
                ? .backward
                : .forward
            }
            selected = item
        }
    }

    private func scrollToSelected(proxy: ScrollViewProxy, animated: Bool) {
        guard let index = items.firstIndex(of: selected) else { return }

        let scroll = {
            if index == items.startIndex {
                proxy.scrollTo(ScrollBoundary.leading, anchor: .leading)
            } else if index == items.index(before: items.endIndex) {
                proxy.scrollTo(ScrollBoundary.trailing, anchor: .trailing)
            } else {
                proxy.scrollTo(selected, anchor: .center)
            }
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.25), scroll)
        } else {
            scroll()
        }
    }
}

private struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Text(title)
            .font(.satoshi.medium.size(12))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background {
                Capsule()
                    .fill(isSelected ? Color(hex: 0x5E9C76) : Color.yellow)
            }
            .overlay {
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : Color.gray.opacity(0.25),
                        lineWidth: 0.8
                    )
            }
            .contentShape(Capsule())
            .onTapGesture(perform: action)
    }
}

private struct PreviewWrapper: View {
    @State private var selected: Genre = .all
    @State private var direction: SlideDirection = .forward

    var body: some View {
        VStack(spacing: 24) {
            SegmentedChipControl(
                selected: $selected,
                direction: $direction,
                items: Genre.allCases
            )

            ZStack {
                Text(selected.title)
                    .font(.satoshi.regular.size(17))
                    .id(selected)
                    .transition(segmentTransition(direction))
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .animation(.easeInOut(duration: 0.25), value: selected)
        }
    }
}

extension Genre: SegmentedItem {

    var title: String { displayName }

}

extension View {

    func segmentTransition(_ direction: SlideDirection) -> AnyTransition {
        let insertion: Edge = direction == .forward ? .trailing : .leading
        let removal: Edge = direction == .forward ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: insertion).combined(with: .opacity),
            removal: .move(edge: removal).combined(with: .opacity)
        )
    }

}

#Preview {
    PreviewWrapper()
}
