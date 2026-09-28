//
//  AboutSettingsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.09.2026.
//

import SwiftUI

struct AboutSettingsView: View {

    // MARK: - Properties. Public

    let settingsVM: SettingsManaging
    @Binding var isFeedbackPresented: Bool

    // MARK: - Main Body

    var body: some View {
        Form {
            Section {
                SettingsRow(
                    title: L10n.Settings.license,
                    systemImage: "checkmark.seal.fill",
                    systemImageSize: Constants.rowIconSize
                ) {
                    settingsVM.presentPaywall()
                }

                SettingsRow(
                    title: L10n.Settings.shareFeedback,
                    systemImage: "square.and.pencil",
                    systemImageSize: Constants.rowIconSize
                ) {
                    isFeedbackPresented = true
                }

                shareRow

                SettingsRow(title: L10n.Settings.privacy) {
                    settingsVM.privacyPolicyURL.map { openURL($0) }
                }

                SettingsRow(title: L10n.Settings.terms) {
                    settingsVM.termsOfUseURL.map { openURL($0) }
                }

                SettingsRow(
                    title: L10n.Settings.version,
                    value: settingsVM.marketingVersion,
                    showsSystemImage: false
                )
            }
        }
        .listSectionSpacing(.compact)
        .environment(\.defaultMinListRowHeight, 1)
        .customNavigationTitle(L10n.Settings.aboutTitle)
    }

    // MARK: - Properties. Private

    @Environment(\.openURL) private var openURL

    @ViewBuilder
    private var shareRow: some View {
        if let appStoreURL = settingsVM.shareURL {
            ShareLink(
                item: appStoreURL,
                subject: Text(Constants.shareAppTitle),
                message: Text(L10n.Settings.shareMessage)
            ) {
                shareSettingsRow
            }
            .buttonStyle(.plain)
        } else if let privacyURL = settingsVM.privacyPolicyURL {
            ShareLink(
                item: "\(L10n.Settings.shareMessage)\n\(privacyURL.absoluteString)"
            ) {
                shareSettingsRow
            }
            .buttonStyle(.plain)
        }
    }

    private var shareSettingsRow: some View {
        SettingsRow(
            title: L10n.Settings.share,
            systemImage: "square.and.arrow.up",
            systemImageSize: Constants.rowIconSize
        )
    }

    private enum Constants {
        static let shareAppTitle = "TuneBox"
        static let rowIconSize: CGFloat = 19.5
    }
}

#Preview {
    NavigationStack {
        AboutSettingsView(
            settingsVM: SettingsViewModel(),
            isFeedbackPresented: .constant(false)
        )
    }
}
