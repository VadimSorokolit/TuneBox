//
//  SettingsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import SwiftUI
import Resolver
import UIKit

private enum SettingsRoute: Hashable {
    case about
}

struct SettingsView: View {

    // MARK: - Main Body

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                HeaderView()

                SectionsView(
                    settingsVM: settingsVM,
                    rootTabsVM: rootTabsVM,
                    isSleepTimerPresented: $isSleepTimerPresented,
                    path: $path
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                    case .about:
                        AboutSettingsView(
                            settingsVM: settingsVM,
                            isFeedbackPresented: $isFeedbackPresented,
                            isSharePresented: $isSharePresented
                        )
                }
            }
        }
        .sheet(isPresented: $isFeedbackPresented) {
            FeedbackSheetView(settingsVM: settingsVM) {
                isFeedbackPresented = false
            }
        }
        .sheet(isPresented: $isSharePresented) {
            ActivityView(activityItems: settingsVM.shareActivityItems)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isSleepTimerPresented) {
            SleepTimerSheetView(settingsVM: settingsVM) {
                isSleepTimerPresented = false
            }
        }
    }

    // MARK: - Properties. Private

    @Injected private var settingsVM: SettingsManaging
    @Injected private var rootTabsVM: RootTabsManaging
    @State private var path = [SettingsRoute]()
    @State private var isFeedbackPresented = false
    @State private var isSharePresented = false
    @State private var isSleepTimerPresented = false

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
        @Binding var isSleepTimerPresented: Bool
        @Binding var path: [SettingsRoute]

        // MARK: - Body

        var body: some View {
            VStack(spacing: .zero) {
                Form {
                    Section(header: Text("Appearance")) {
                        SettingsRow(
                            title: "Theme",
                            trailingText: themeManager.preset.displayName,
                            selection: themeBinding,
                            options: ThemePreset.allCases.map { ($0, $0.displayName) }
                        )

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

                    Section(header: Text("Playback")) {
                        SettingsRow(
                            title: "Sleep Timer",
                            value: settingsVM.sleepTimerTrailingText,
                            showsSystemImage: false
                        ) {
                            isSleepTimerPresented = true
                        }
                    }

                    Section(header: Text("About")) {
                        SettingsRow(title: "App Info") {
                            path.append(.about)
                        }
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

        @Environment(\.themeManager) private var themeManager
        @State private var tabsMode: TabsMode = .allTabs
        @State private var defaultTab: CustomTab = .default

        private var themeBinding: Binding<ThemePreset> {
            Binding(
                get: { themeManager.preset },
                set: { themeManager.setPreset($0) }
            )
        }

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

    private struct ActivityView: UIViewControllerRepresentable {

        let activityItems: [Any]

        func makeUIViewController(
            context: Context
        ) -> UIActivityViewController {
            UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
        }

        func updateUIViewController(
            _ uiViewController: UIActivityViewController,
            context: Context
        ) {}
    }
}

#Preview {
    SettingsView()
}
