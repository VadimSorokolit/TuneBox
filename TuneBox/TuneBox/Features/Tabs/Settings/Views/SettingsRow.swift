//
//  SettingsRow.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.09.2026.
//

import SwiftUI

struct SettingsRow: View {

    // MARK: - Properties. Public

    let title: String
    var subtitle: String?
    var value: String?
    var showsChevron: Bool = true
    var isDisabled: Bool = false
    var action: (() -> Void)?

    // MARK: - Main Body

    var body: some View {
        if let action {
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

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    Form {
        SettingsRow(title: "Privacy Policy", action: {})
        SettingsRow(
            title: "Version",
            value: "1.0",
            showsChevron: false
        )
    }
}
