//
//  SegmentedControl.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 16.07.2026.
//

import SwiftUI

struct SegmentedControl<T>: View where T: SegmentedItem & RawRepresentable, T.RawValue == Int {

    // MARK: - Properties. Public

    @Binding var selected: T
    @Binding var direction: SlideDirection
    let items: [T]

    // MARK: - Main Body

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { segment in
                Button {
                    withAnimation(.snappy(duration: 0.28)) {
                        direction = segment.rawValue > selected.rawValue
                            ? .backward
                            : .forward
                        selected = segment
                    }
                } label: {
                    Text(segment.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(
                            selected == segment
                                ? Color.primary.opacity(0.9)
                                : Color.primary.opacity(0.45)
                        )
                        .animation(nil, value: selected)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if selected == segment {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                            .matchedGeometryEffect(id: "segmentPill", in: namespace)
                    }
                }
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    // MARK: - Properties. Private

    @Namespace private var namespace
}

    // MARK: - Objects. Private (For Preview)

private struct SegmentedControlPreview: View {
    private enum PreviewSegment: Int, CaseIterable, SegmentedItem {
        case first
        case second

        var title: String {
            switch self {
                case .first:
                    "First"
                case .second:
                    "Second"
            }
        }
    }

    @State private var selected: PreviewSegment = .first
    @State private var direction: SlideDirection = .forward

    var body: some View {
        VStack(spacing: 24) {
            SegmentedControl(
                selected: $selected,
                direction: $direction,
                items: PreviewSegment.allCases
            )

            ZStack {
                Text(selected.title + " Content")
                    .id(selected)
                    .segmentTransition(direction)
            }
            .font(.title3.weight(.medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 120)
            .animation(.easeInOut(duration: 0.25), value: selected)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()

        SegmentedControlPreview()
    }
}
