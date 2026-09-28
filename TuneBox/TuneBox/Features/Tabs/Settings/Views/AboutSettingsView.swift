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
    @Binding var isSharePresented: Bool

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

                SettingsRow(
                    title: L10n.Settings.share,
                    systemImage: "square.and.arrow.up"
                ) {
                    isSharePresented = true
                }

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
}

#Preview {
    NavigationStack {
        AboutSettingsView(
            settingsVM: SettingsViewModel(),
            isFeedbackPresented: .constant(false),
            isSharePresented: .constant(false)
        )
    }
}
