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
                    systemImage: "checkmark.seal.fill"
                ) {
                    settingsVM.presentPaywall()
                }

                SettingsRow(
                    title: L10n.Settings.shareFeedback,
                    systemImage: "square.and.pencil"
                ) {
                    isFeedbackPresented = true
                }

                ShareLink(
                    item: Constants.shareAppURL,
                    subject: Text(Constants.shareAppTitle),
                    message: Text(L10n.Settings.shareMessage),
                    preview: SharePreview(
                        Constants.shareAppTitle,
                        image: Image(Constants.shareAppImageName)
                    )
                ) {
                    SettingsRow(
                        title: L10n.Settings.share,
                        systemImage: "square.and.arrow.up"
                    )
                }
                .buttonStyle(.plain)

                SettingsRow(title: L10n.Settings.privacy) {
                    if let url = settingsVM.privacyPolicyURL {
                        openURL(url)
                    }
                }

                SettingsRow(title: L10n.Settings.terms) {
                    openURL(settingsVM.termsOfUseURL)
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
        /// Replace with the real App Store ID when available.
        static let shareAppURL = URL(string: "https://apps.apple.com/app/tunebox/id000000000")!
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
