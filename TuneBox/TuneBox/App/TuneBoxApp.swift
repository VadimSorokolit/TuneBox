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
    @State private var coordinator = AppCoordinator(root: .main)
    @Injected private var viewModel: TransferManaging
    @Injected private var playerViewModel: PlayerManaging

    var body: some Scene {
        WindowGroup {
            RootTabsView()
                .environment(\.themeManager, themeManager)
                .applyTheme(themeManager)
                .environment(coordinator)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                        case .active:
                            Task {
                                await viewModel.restoreDownloadsOnForeground()
                            }
                            AppLogger.app.info("App is active")

                        case .inactive:
                            viewModel.saveTransferState()
                            playerViewModel.persistPlaybackSession()
                            AppLogger.app.info("App is inactive")

                        case .background:
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
