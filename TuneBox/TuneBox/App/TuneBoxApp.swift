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
    @Injected private var viewModel: TransferManaging
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootTabsView()
                .environment(\.themeManager, themeManager)
                .applyTheme(themeManager)
                .overlay {
                    if viewModel.isLoading {
                        SpinnerView()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                        case .active:
                            if viewModel.popularTracks.isEmpty == false {
                                Task {
                                    await viewModel.restoreDownloadsOnForeground()
                                }
                            }
                            AppLogger.app.info("App is active")

                        case .inactive:
                            viewModel.saveTransferState()
                            AppLogger.app.info("App is inactive")

                        case .background:
                            viewModel.saveTransferState()
                            AppLogger.app.info("App moved to background")

                        @unknown default:
                            AppLogger.app.warning("Unknown app state")
                    }
                }
        }
    }

}
