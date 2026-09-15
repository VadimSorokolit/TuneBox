//
//  SettingsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import SwiftUI
import Resolver

struct SettingsView: View {

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            SectionsView(settingsVM: settingsVM)
        }
    }

    // MARK: - Properties. Private

    @Injected private var settingsVM: SettingsManaging

    // MARK: - Objects. Private

    private struct HeaderView: View {

        // MARK: - Body

        var body: some View {
            TabHeaderView(title: "Settings")
        }
    }

    private struct SectionsView: View {

        // MARK: - Properties. Public

        let settingsVM: SettingsManaging

        // MARK: - Body

        var body: some View {
            VStack(spacing: .zero) {
                Form {
                    Section(header: Text("About")) {
                        SettingsRow(title: "Privacy Policy") {
                            settingsVM.openPrivacy()
                        }

                        SettingsRow(title: "Terms of Use") {
                            settingsVM.openTerms()
                        }
                    }
                }
                .listSectionSpacing(.compact)
            }
        }
    }
}

#Preview {
    SettingsView()
}
