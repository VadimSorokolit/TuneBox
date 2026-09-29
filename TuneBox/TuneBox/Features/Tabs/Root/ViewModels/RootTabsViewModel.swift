//
//  RootTabsViewModel.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 10.08.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class RootTabsViewModel: RootTabsManaging {

    // MARK: - Properties. Public

    private(set) var tabsMode: TabsMode = .allTabs
    private(set) var defaultTab: CustomTab = .default

    var visibleTabs: [CustomTab] {
        switch self.tabsMode {
            case .allTabs:
                CustomTab.allCases

            case .import:
                [.importFiles]
        }
    }

    var isTabBarVisible: Bool {
        self.visibleTabs.count > 1
    }

    let tabBarHeight: CGFloat = GlobalConstants.Screen.defaultHeight
    let playerHeight: CGFloat = GlobalConstants.CompactPlayer.height

    // MARK: - Initializer

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.tabsMode = Self.readTabsMode(from: userDefaults)
        self.defaultTab = Self.readDefaultTab(from: userDefaults)
        self.observeUserDefaultsChanges()
    }

    // MARK: - Methods. Public

    func setTabsMode(_ mode: TabsMode) {
        guard self.tabsMode != mode else { return }

        self.userDefaults.set(mode.rawValue, forKey: Constants.Keys.tabsMode)
        self.tabsMode = mode

        if mode == .import {
            self.setDefaultTab(.importFiles)
        }
    }

    func setDefaultTab(_ tab: CustomTab) {
        let resolved = self.visibleTabs.contains(tab) ? tab : .default

        guard self.defaultTab != resolved else { return }

        self.userDefaults.set(resolved.rawValue, forKey: Constants.Keys.defaultTab)
        self.defaultTab = resolved
    }

    func reloadTabsMode() {
        let mode = Self.readTabsMode(from: self.userDefaults)

        guard self.tabsMode != mode else {
            return
        }

        self.tabsMode = mode
    }

    func rememberSelectedTab(_ tab: CustomTab) {
        self.userDefaults.set(
            tab.rawValue,
            forKey: Constants.Keys.lastSelectedTab
        )
    }

    func markBackgrounded() {
        AppResume.markBackgrounded(defaults: self.userDefaults)
    }

    func restoreSelectedTab() -> CustomTab {
        self.reloadTabsMode()
        self.defaultTab = Self.readDefaultTab(from: self.userDefaults)
        return Self.configuredDefaultTab(from: self.userDefaults)
    }

    static func startupSelectedTab(
        from defaults: UserDefaults = .standard
    ) -> CustomTab {
        if AppResume.isQuickResume(defaults: defaults),
           let last = Self.readLastSelectedTab(from: defaults),
           Self.isTabAvailable(last, in: defaults) {
            return last
        }

        return Self.configuredDefaultTab(from: defaults)
    }

    static func isQuickResume(
        from defaults: UserDefaults = .standard
    ) -> Bool {
        AppResume.isQuickResume(defaults: defaults)
    }

    func bottomInset(base: CGFloat, isPlayerVisible: Bool, isPlaying: Bool) -> CGFloat {
        base
            + (self.isTabBarVisible ? self.tabBarHeight : 0)
            + (isPlayerVisible
               ? GlobalConstants.CompactPlayer.height
               : 0
            )
    }

    // MARK: - Properties. Private

    private enum Constants {
        enum Keys {
            static let tabsMode = "tabsMode"
            static let defaultTab = "defaultTab"
            static let lastSelectedTab = "lastSelectedTab"
        }
    }

    @ObservationIgnored
    private let userDefaults: UserDefaults

    @ObservationIgnored
    private var defaultsObserver: NSObjectProtocol?

    // MARK: - Methods. Private

    private func observeUserDefaultsChanges() {
        self.defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            MainActor.assumeIsolated {
                self.reloadTabsMode()
                self.defaultTab = Self.readDefaultTab(from: self.userDefaults)
            }
        }
    }

    private static func configuredDefaultTab(
        from defaults: UserDefaults
    ) -> CustomTab {
        switch Self.readTabsMode(from: defaults) {
            case .import:
                return .importFiles

            case .allTabs:
                let tab = Self.readDefaultTab(from: defaults)
                return Self.isTabAvailable(tab, in: defaults) ? tab : .default
        }
    }

    private static func isTabAvailable(
        _ tab: CustomTab,
        in defaults: UserDefaults
    ) -> Bool {
        switch Self.readTabsMode(from: defaults) {
            case .import:
                return tab == .importFiles

            case .allTabs:
                return CustomTab.allCases.contains(tab)
        }
    }

    private static func readTabsMode(from defaults: UserDefaults) -> TabsMode {
        let raw = defaults.string(forKey: Constants.Keys.tabsMode) ?? TabsMode.allTabs.rawValue

        return TabsMode(rawValue: raw) ?? .allTabs
    }

    private static func readDefaultTab(from defaults: UserDefaults) -> CustomTab {
        if let raw = defaults.string(forKey: Constants.Keys.defaultTab),
           let tab = CustomTab(rawValue: raw) {
            return tab
        }

        return .default
    }

    private static func readLastSelectedTab(
        from defaults: UserDefaults
    ) -> CustomTab? {
        guard let raw = defaults.string(forKey: Constants.Keys.lastSelectedTab) else {
            return nil
        }

        return CustomTab(rawValue: raw)
    }
}
