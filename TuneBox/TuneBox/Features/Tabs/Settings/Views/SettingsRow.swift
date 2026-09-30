//
//  SettingsRow.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.09.2026.
//

import SwiftUI
import UIKit

struct SettingsRow: View {

    // MARK: - Properties. Public

    let title: String
    var subtitle: String?
    var value: String?
    var trailingText: String?
    var systemImage = "chevron.right"
    var systemImageSize: CGFloat = 13
    var showsSystemImage: Bool = true
    var isDisabled: Bool = false
    var action: (() -> Void)?
    var titleLineLimitRange: ClosedRange<Int>?
    var trailingTextLineLimitRange: ClosedRange<Int>?

    // MARK: - Initializers

    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        trailingText: String? = nil,
        systemImage: String = "chevron.right",
        systemImageSize: CGFloat = 13,
        showsSystemImage: Bool = true,
        isDisabled: Bool = false,
        titleLineLimitRange: ClosedRange<Int>? = nil,
        trailingTextLineLimitRange: ClosedRange<Int>? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.trailingText = trailingText
        self.systemImage = systemImage
        self.systemImageSize = systemImageSize
        self.showsSystemImage = showsSystemImage
        self.isDisabled = isDisabled
        self.titleLineLimitRange = titleLineLimitRange
        self.trailingTextLineLimitRange = trailingTextLineLimitRange
        self.action = action
        self.menu = nil
    }

    init<Selection: Hashable>(
        title: String,
        trailingText: String,
        systemImage: String = "chevron.up.chevron.down",
        isDisabled: Bool = false,
        titleLineLimitRange: ClosedRange<Int>? = nil,
        trailingTextLineLimitRange: ClosedRange<Int>? = nil,
        selection: Binding<Selection>,
        options: [(Selection, String)]
    ) {
        self.title = title
        self.subtitle = nil
        self.value = nil
        self.trailingText = trailingText
        self.systemImage = systemImage
        self.showsSystemImage = true
        self.isDisabled = isDisabled
        self.action = nil
        self.systemImageSize = 13
        self.titleLineLimitRange = titleLineLimitRange
        self.trailingTextLineLimitRange = trailingTextLineLimitRange
        self.menu = UIMenu(
            children: options.map { value, title in
                UIAction(
                    title: title,
                    state: selection.wrappedValue == value ? .on : .off
                ) { _ in
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        selection.wrappedValue = value
                    }
                }
            }
        )
    }

    // MARK: - Main Body

    var body: some View {
        row
            .modifier(
                SettingsRowLayoutModifier(isCompactSE: isCompactSE,
                                          hasMenu: menu != nil)
            )
    }

    // MARK: - Properties. Private

    @Environment(\.screenHeight) private var screenHeight

    private let menu: UIMenu?

    private enum Constants {
        static let rowFont: Font = .system(size: 17, weight: .regular)
    }

    private var isCompactSE: Bool {
        screenHeight > 0 && screenHeight <= GlobalConstants.Screen.seHeight
    }

    @ViewBuilder
    private var row: some View {
        if let menu {
            ZStack {
                // Hit target under the label so menu dismiss can't flash the title.
                TrailingAnchorMenuButton(
                    menu: menu,
                    isEnabled: isDisabled.isFalse
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                rowContent
                    .allowsHitTesting(false)
                    .opacity(isDisabled ? 0.45 : 1)
                    .compositingGroup()
            }
            .contentShape(Rectangle())
            .transaction { $0.animation = nil }
            .animation(nil, value: trailingText)
            .animation(nil, value: isDisabled)
        } else if let action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 8) {
            titleLabel

            Spacer(minLength: 8)

            if let value, value.isNotEmpty {
                Text(value)
                    .lineLimit(1)
                    .font(Constants.rowFont)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            if showsSystemImage {
                if let trailingText, trailingText.isNotEmpty {
                    trailingTextLabel(trailingText)
                }

                Image(systemName: systemImage)
                    .font(.system(size: systemImageSize, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var titleLabel: some View {
        let text = Text(title)
            .font(Constants.rowFont)
            .foregroundStyle(.primary)
            .transaction { $0.animation = nil }

        if let titleLineLimitRange {
            text
                .lineLimit(titleLineLimitRange)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            text.lineLimit(1)
        }
    }

    @ViewBuilder
    private func trailingTextLabel(_ trailingText: String) -> some View {
        let text = Text(trailingText)
            .foregroundStyle(.secondary)
            .font(Constants.rowFont)
            .transaction { $0.animation = nil }

        if let trailingTextLineLimitRange {
            text
                .lineLimit(trailingTextLineLimitRange)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            text
                .lineLimit(1)
                .fixedSize()
        }
    }
}

// MARK: - SettingsRowLayoutModifier

private struct SettingsRowLayoutModifier: ViewModifier {

    let isCompactSE: Bool
    let hasMenu: Bool

    func body(content: Content) -> some View {
        if isCompactSE {
            content
                .frame(maxWidth: .infinity, minHeight: 30)
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                .listRowBackground(Color(.secondarySystemGroupedBackground))
        } else if hasMenu {
            content
                .frame(maxWidth: .infinity, minHeight: 44)
                // Match leading title inset with trailing icon inset.
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color(.secondarySystemGroupedBackground))
        } else {
            content
        }
    }
}

// MARK: - TrailingAnchorMenuButton

/// Full-row tap target that presents `UIMenu` from the trailing edge.
private final class TrailingMenuHostView: UIView {

    let button = TrailingMenuHostButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .clear

        button.showsMenuAsPrimaryAction = true
        button.backgroundColor = .clear
        button.expandedHitAreaSource = self
        addSubview(button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Narrow trailing frame forces the system menu to open on the right.
        let width: CGFloat = 1
        button.frame = CGRect(
            x: bounds.maxX - width,
            y: 0,
            width: width,
            height: max(bounds.height, 1)
        )
    }
}

private final class TrailingMenuHostButton: UIButton {

    weak var expandedHitAreaSource: UIView?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let host = expandedHitAreaSource else {
            return super.point(inside: point, with: event)
        }

        // Accept taps anywhere in the row while keeping a trailing-only frame.
        let hostPoint = convert(point, to: host)
        return host.bounds.contains(hostPoint)
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        suppressEnclosingListHighlight()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        suppressEnclosingListHighlight()
    }

    override func menuAttachmentPoint(
        for configuration: UIContextMenuConfiguration
    ) -> CGPoint {
        CGPoint(x: bounds.maxX, y: bounds.midY)
    }

    override var isHighlighted: Bool {
        get { false }
        set {}
    }

    override var isSelected: Bool {
        get { false }
        set {}
    }

    func suppressEnclosingListHighlight() {
        var current: UIView? = superview

        while let view = current {
            if let cell = view as? UITableViewCell {
                cell.selectionStyle = .none
                cell.isHighlighted = false
                cell.isSelected = false
                cell.contentView.alpha = 1
                cell.layer.removeAllAnimations()
                cell.contentView.layer.removeAllAnimations()
                return
            }

            if let cell = view as? UICollectionViewListCell {
                cell.automaticallyUpdatesBackgroundConfiguration = false
                cell.isHighlighted = false
                cell.isSelected = false
                cell.contentView.alpha = 1
                cell.layer.removeAllAnimations()
                cell.contentView.layer.removeAllAnimations()
                cell.configurationUpdateHandler = { cell, _ in
                    var background = UIBackgroundConfiguration.listCell()
                    background.backgroundColor = .secondarySystemGroupedBackground
                    cell.backgroundConfiguration = background
                    cell.isHighlighted = false
                    cell.isSelected = false
                    cell.contentView.alpha = 1
                }
                var background = UIBackgroundConfiguration.listCell()
                background.backgroundColor = .secondarySystemGroupedBackground
                cell.backgroundConfiguration = background
                return
            }

            current = view.superview
        }
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        animator?.addCompletion { [weak self] in
            self?.suppressEnclosingListHighlight()
        }
        suppressEnclosingListHighlight()
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(rect: .zero)
        return UITargetedPreview(view: self, parameters: parameters)
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(rect: .zero)
        return UITargetedPreview(view: self, parameters: parameters)
    }
}

private struct TrailingAnchorMenuButton: UIViewRepresentable {

    let menu: UIMenu
    var isEnabled: Bool = true

    func makeUIView(context: Context) -> TrailingMenuHostView {
        let host = TrailingMenuHostView()
        host.button.menu = menu
        host.button.isEnabled = isEnabled
        host.isUserInteractionEnabled = isEnabled
        return host
    }

    func updateUIView(_ uiView: TrailingMenuHostView, context: Context) {
        uiView.button.menu = menu
        uiView.button.isEnabled = isEnabled
        uiView.isUserInteractionEnabled = isEnabled
        DispatchQueue.main.async {
            uiView.button.suppressEnclosingListHighlight()
        }
    }
}

#Preview {
    Form {
        SettingsRow(title: "Privacy Policy", action: {})

        SettingsRow(
            title: "Version",
            value: "1.0",
            showsSystemImage: false
        )

        SettingsRow(
            title: "Visible Tabs",
            trailingText: "All Tabs",
            selection: .constant("All Tabs"),
            options: [
                ("All Tabs", "All Tabs"),
                ("Import", "Import")
            ]
        )
    }
}
