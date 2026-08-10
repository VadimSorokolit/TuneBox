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

    let tabBarHeight: CGFloat = 60
    let playerHeight: CGFloat = GlobalConstants.Screen.defaultBottomPadding

    // MARK: - Initializer

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.tabsMode = Self.readTabsMode(from: userDefaults)
        self.observeUserDefaultsChanges()
    }

    // MARK: - Methods. Public

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

    func restoreSelectedTab() -> CustomTab {
        self.reloadTabsMode()

        switch self.tabsMode {
            case .import:
                return .importFiles

            case .allTabs:
                let raw = self.userDefaults.string(
                    forKey: Constants.Keys.lastSelectedTab
                )
                let restored = CustomTab(rawValue: raw ?? "") ?? .browse

                return self.visibleTabs.contains(restored) ? restored : .browse
        }
    }

    func bottomInset(base: CGFloat, isPlayerVisible: Bool) -> CGFloat {
        base
            + (self.isTabBarVisible ? self.tabBarHeight : 0)
            + (isPlayerVisible ? self.playerHeight : 0)
    }

    // MARK: - Properties. Private

    private enum Constants {
        enum Keys {
            static let tabsMode = "tabsMode"
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
            }
        }
    }

    private static func readTabsMode(from defaults: UserDefaults) -> TabsMode {
        let raw = defaults.string(forKey: Constants.Keys.tabsMode) ?? TabsMode.allTabs.rawValue

        return TabsMode(rawValue: raw) ?? .allTabs
    }
}
