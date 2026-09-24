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

            SectionsView(
                settingsVM: settingsVM,
                rootTabsVM: rootTabsVM,
                isFeedbackPresented: $isFeedbackPresented
            )
        }
        .sheet(isPresented: $isFeedbackPresented) {
            FeedbackSheetView {
                isFeedbackPresented = false
            }
        }
    }

    // MARK: - Properties. Private

    @Injected private var settingsVM: SettingsManaging
    @Injected private var rootTabsVM: RootTabsManaging
    @State private var isFeedbackPresented = false

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
        let rootTabsVM: RootTabsManaging
        @Binding var isFeedbackPresented: Bool

        // MARK: - Body

        var body: some View {
            VStack(spacing: .zero) {
                Form {
                    Section(header: Text("Appearance")) {
                        SettingsRow(
                            title: "Default Tab",
                            trailingText: rootTabsVM.defaultTab.title
                        ) {
                            Picker(
                                "Default Tab",
                                selection: Binding(
                                    get: { rootTabsVM.defaultTab },
                                    set: { rootTabsVM.setDefaultTab($0) }
                                )
                            ) {
                                ForEach(rootTabsVM.visibleTabs) { tab in
                                    Text(tab.title)
                                        .tag(tab)
                                }
                            }
                        }
                        .disabled(rootTabsVM.tabsMode == .import)

                        SettingsRow(
                            title: "Visible Tabs",
                            trailingText: rootTabsVM.tabsMode.title
                        ) {
                            Picker(
                                "Visible Tabs",
                                selection: Binding(
                                    get: { rootTabsVM.tabsMode },
                                    set: { rootTabsVM.setTabsMode($0) }
                                )
                            ) {
                                ForEach(TabsMode.allCases) { mode in
                                    Text(mode.title)
                                        .tag(mode)
                                }
                            }
                        }
                    }

                    Section(header: Text("About")) {
                        SettingsRow(title: "Share Feedback") {
                            isFeedbackPresented = true
                        }

                        SettingsRow(title: "Privacy Policy") {
                            settingsVM.openPrivacy()
                        }

                        SettingsRow(title: "Terms of Use") {
                            settingsVM.openTerms()
                        }

                        SettingsRow(
                            title: "Version",
                            value: settingsVM.marketingVersion,
                            showsSystemImage: false
                        )
                    }
                }
                .listSectionSpacing(.compact)
            }
            .padding(.top, 10)
        }
    }
}

#Preview {
    SettingsView()
}
