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

                settingsVM.shareURL.map { shareURL in
                    ShareLink(
                        item: shareURL,
                        subject: Text(Constants.shareAppTitle),
                        message: Text(L10n.Settings.shareMessage),
                        preview: SharePreview(
                            Constants.shareAppTitle,
                            image: Image(Constants.shareAppImageName)
                        )
                    ) {
                        SettingsRow(
                            title: L10n.Settings.share,
                            systemImage: "square.and.arrow.up",
                            systemImageSize: Constants.rowIconSize
                        )
                    }
                    .buttonStyle(.plain)
                }

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

    private enum Constants {
        static let shareAppTitle = "TuneBox"
        static let shareAppImageName = "Paywall"
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
