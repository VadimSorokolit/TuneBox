//
//  SettingsRow.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.09.2026.
//

import SwiftUI

struct SettingsRow<MenuContent: View>: View {

    // MARK: - Properties. Public

    let title: String
    var subtitle: String?
    var value: String?
    var trailingText: String?
    var systemImage = "chevron.right"
    var showsSystemImage: Bool = true
    var isDisabled: Bool = false
    var action: (() -> Void)?
    @ViewBuilder var menuContent: () -> MenuContent

    // MARK: - Initializers

    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        trailingText: String? = nil,
        systemImage: String = "chevron.right",
        showsSystemImage: Bool = true,
        isDisabled: Bool = false,
        action: (() -> Void)? = nil
    ) where MenuContent == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.trailingText = trailingText
        self.systemImage = systemImage
        self.showsSystemImage = showsSystemImage
        self.isDisabled = isDisabled
        self.action = action
        self.menuContent = { EmptyView() }
        self.hasMenu = false
    }

    init(
        title: String,
        subtitle: String? = nil,
        trailingText: String,
        systemImage: String = "chevron.up.chevron.down",
        isDisabled: Bool = false,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = nil
        self.trailingText = trailingText
        self.systemImage = systemImage
        self.showsSystemImage = true
        self.isDisabled = isDisabled
        self.action = nil
        self.menuContent = menuContent
        self.hasMenu = true
    }

    // MARK: - Main Body

    var body: some View {
        if hasMenu {
            Menu {
                menuContent()
            } label: {
                rowContent
            }
            .tint(.primary)
            .disabled(isDisabled)
        } else if let action {
            Button(action: action) {
                rowContent
            }
            .tint(.primary)
            .disabled(isDisabled)
        } else {
            rowContent
        }
    }

    // MARK: - Properties. Private

    private let hasMenu: Bool

    private var rowContent: some View {
        HStack(spacing: 8) {
            VStack(
                alignment: .leading,
                spacing: subtitle.isNotNil ? 4 : 0
            ) {
                HStack(spacing: 8) {
                    Text(title)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    if let value, value.isNotEmpty {
                        Text(value)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }

            if showsSystemImage {
                HStack(spacing: trailingText?.isNotEmpty == true ? 4 : 0) {
                    if let trailingText, trailingText.isNotEmpty {
                        Text(trailingText)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: systemImage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
            title: "Tabs Mode",
            trailingText: "All Tabs"
        ) {
            Picker("Tabs Mode", selection: .constant("All Tabs")) {
                Text("All Tabs").tag("All Tabs")
                Text("Import").tag("Import")
            }
        }
    }
}
