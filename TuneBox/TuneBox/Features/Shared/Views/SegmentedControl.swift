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
        GlassEffectContainer(spacing: Constants.containerSpacing) {
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
                                    ? theme.tokens.primaryText.opacity(0.9)
                                    : theme.tokens.secondaryText
                            )
                            .animation(nil, value: selected)
                            .frame(maxWidth: .infinity)
                            .frame(height: Constants.segmentHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background {
                        if selected == segment {
                            RoundedRectangle(
                                cornerRadius: Constants.selectedCornerRadius,
                                style: .continuous
                            )
                            .glassEffect(
                                .regular.tint(selectedGlassTint).interactive(),
                                in: .rect(cornerRadius: Constants.selectedCornerRadius)
                            )
                            .glassEffectID("segmentPill", in: namespace)
                        }
                    }
                }
            }
            .padding(Constants.containerPadding)
            .glassEffect(
                .regular.tint(trackGlassTint),
                in: .rect(cornerRadius: Constants.trackCornerRadius)
            )
        }
    }

    // MARK: - Properties. Private

    @Environment(\.themeManager) private var theme
    @Namespace private var namespace

    private var trackGlassTint: Color {
        theme.tokens.cellBackground.opacity(
            theme.systemColorScheme == .dark ? 0.55 : 0.9
        )
    }

    private var selectedGlassTint: Color {
        theme.systemColorScheme == .dark
            ? Color.white.opacity(0.22)
            : Color.white.opacity(0.82)
    }

    private enum Constants {
        static let segmentHeight: CGFloat = 22
        static let containerPadding: CGFloat = 4
        static let containerSpacing: CGFloat = 4
        static let selectedCornerRadius: CGFloat = 12
        static let trackCornerRadius: CGFloat = 16
    }
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
    @Previewable @State var themeManager = ThemeManager()

    ZStack {
        themeManager.tokens.appBackground.ignoresSafeArea()

        SegmentedControlPreview()
    }
    .environment(\.themeManager, themeManager)
}
