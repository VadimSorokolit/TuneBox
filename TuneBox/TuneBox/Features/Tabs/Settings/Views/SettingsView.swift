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
            FeedbackSheetView(settingsVM: settingsVM) {
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
        @Environment(\.openURL) private var openURL

        // MARK: - Body

        var body: some View {
            VStack(spacing: .zero) {
                Form {
                    Section(header: Text("Appearance")) {
                        SettingsRow(
                            title: "Default Tab",
                            trailingText: defaultTab.title,
                            isDisabled: tabsMode == .import,
                            selection: defaultTabBinding,
                            options: defaultTabOptions.map { ($0, $0.title) }
                        )

                        SettingsRow(
                            title: "Visible Tabs",
                            trailingText: tabsMode.title,
                            selection: tabsModeBinding,
                            options: TabsMode.allCases.map { ($0, $0.title) }
                        )
                    }

                    Section(header: Text("About")) {
                        SettingsRow(
                            title: "Share Feedback",
                            systemImage: "square.and.pencil"
                        ) {
                            isFeedbackPresented = true
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
            }
            .padding(.top, 10)
            .onAppear {
                tabsMode = rootTabsVM.tabsMode
                defaultTab = rootTabsVM.defaultTab
            }
        }

        // MARK: - Properties. Private

        @State private var tabsMode: TabsMode = .allTabs
        @State private var defaultTab: CustomTab = .default

        private var defaultTabOptions: [CustomTab] {
            switch tabsMode {
                case .allTabs:
                    CustomTab.allCases

                case .import:
                    [.importFiles]
            }
        }

        private var tabsModeBinding: Binding<TabsMode> {
            Binding(
                get: { tabsMode },
                set: { mode in
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        tabsMode = mode
                        rootTabsVM.setTabsMode(mode)
                        defaultTab = rootTabsVM.defaultTab
                    }
                }
            )
        }

        private var defaultTabBinding: Binding<CustomTab> {
            Binding(
                get: { defaultTab },
                set: { tab in
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        rootTabsVM.setDefaultTab(tab)
                        defaultTab = rootTabsVM.defaultTab
                    }
                }
            )
        }
    }
}

#Preview {
    SettingsView()
}
