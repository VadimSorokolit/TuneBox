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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Injected var networkService: NetworkServicing
    @Injected private var viewModel: TransferManaging

    init() {
        appDelegate.configure(networkService: networkService, viewModel: viewModel)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modifier(LoadViewModifer())
        }
    }

    private struct LoadViewModifer: ViewModifier {
        @Environment(\.scenePhase) private var scenePhase
        @Injected private var viewModel: TransferManaging

        func body(content: Content) -> some View {
            content
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                        case .active:
                            Task { @MainActor in
                                await viewModel.restoreDownloadsOnForeground()
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
