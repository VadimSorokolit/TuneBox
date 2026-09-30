//
//  TuneBoxApp.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import SwiftUI
import Resolver

@main
struct TuneBoxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var themeManager = ThemeManager()
    @State private var coordinator = AppCoordinator(
        root: .main,
        selectedTab: RootTabsViewModel.startupSelectedTab()
    )
    @State private var didEnterBackground = false
    @State private var screenHeight: CGFloat = 0
    @Injected private var viewModel: TransferManaging
    @Injected private var playerViewModel: PlayerManaging
    @Injected private var settingsVM: SettingsManaging
    @Injected private var languageVM: LanguageManaging
    @Injected private var rootTabsVM: RootTabsManaging

    var body: some Scene {
        WindowGroup {
            RootTabsView()
                .environment(\.themeManager, themeManager)
                .environment(\.locale, languageVM.locale)
                .environment(\.screenHeight, screenHeight)
                .applyTheme(themeManager)
                .environment(coordinator)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { _, height in
                    if screenHeight > 0 { return }
                    screenHeight = height
                }
                .task {
                    await settingsVM.start()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                        case .active:
                            if didEnterBackground {
                                didEnterBackground = false
                                // Quick reopen: keep current tab. Longer absence: Settings default.
                                if !RootTabsViewModel.isQuickResume() {
                                    coordinator.selectedTab = rootTabsVM.restoreSelectedTab()
                                }
                            }

                            settingsVM.refreshAccessState()

                            Task {
                                await settingsVM.preparePaywall()
                                await viewModel.restoreDownloadsOnForeground()
                            }
                            AppLogger.app.info("App is active")

                        case .inactive:
                            rootTabsVM.markBackgrounded()
                            viewModel.saveTransferState()
                            playerViewModel.persistPlaybackSession()
                            AppLogger.app.info("App is inactive")

                        case .background:
                            didEnterBackground = true
                            rootTabsVM.markBackgrounded()
                            viewModel.saveTransferState()
                            playerViewModel.persistPlaybackSession()
                            AppLogger.app.info("App moved to background")

                        @unknown default:
                            AppLogger.app.warning("Unknown app state")
                    }
                }
        }
    }
}
