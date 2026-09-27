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
                    title: "License",
                    systemImage: "checkmark.seal.fill"
                ) {
                    settingsVM.presentPaywall()
                }

                SettingsRow(
                    title: "Share Feedback",
                    systemImage: "square.and.pencil"
                ) {
                    isFeedbackPresented = true
                }

                SettingsRow(
                    title: "Share",
                    systemImage: "square.and.arrow.up"
                ) {
                    isSharePresented = true
                }

                SettingsRow(title: "Privacy Policy") {
                    if let url = settingsVM.privacyPolicyURL {
                        openURL(url)
                    }
                }

                SettingsRow(title: "Terms of Use") {
                    openURL(settingsVM.termsOfUseURL)
                }

                SettingsRow(
                    title: "Version",
                    value: settingsVM.marketingVersion,
                    showsSystemImage: false
                )
            }
        }
        .listSectionSpacing(.compact)
        .customNavigationTitle("About")
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
