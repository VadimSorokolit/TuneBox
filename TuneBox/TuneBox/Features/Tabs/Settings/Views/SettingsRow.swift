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
    let action: () -> Void

    // MARK: - Main Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(
                    alignment: .leading,
                    spacing: subtitle.isNotNil ? 4 : 0
                ) {
                    HStack(spacing: 8) {
                        Text(title)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 8)

                        if let value {
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
}

#Preview {
    SettingsRow(
        title: "Privacy Policy",
        subtitle: "Hello",
        value: "dddddddddddddddddddddddrt4trt",
        showsChevron: true,
        action: {}
    )
}
