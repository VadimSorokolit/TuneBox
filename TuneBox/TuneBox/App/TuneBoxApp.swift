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
    @Injected var networkService: NetworkServicing
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        appDelegate.configure(networkService: networkService)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modifier(LoadViewModifer())
        }
    }

    private struct LoadViewModifer: ViewModifier {
        @Environment(\.scenePhase) private var scenePhase

        func body(content: Content) -> some View {
            content
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                        case .active:
                            AppLogger.app.info("App is active")

                        case .inactive:
                            AppLogger.app.info("App is inactive")

                        case .background:
                            AppLogger.app.info("App moved to background")

                        @unknown default:
                            AppLogger.app.warning("Unknown app state")
                    }
                }
        }
    }
}
