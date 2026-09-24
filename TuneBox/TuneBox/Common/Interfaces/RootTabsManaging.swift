//
//  RootTabsManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 10.08.2026.
//

import Foundation
import CoreGraphics

@MainActor
protocol RootTabsManaging: AnyObject {
    var tabsMode: TabsMode { get }
    var defaultTab: CustomTab { get }
    var visibleTabs: [CustomTab] { get }
    var isTabBarVisible: Bool { get }
    var tabBarHeight: CGFloat { get }
    var playerHeight: CGFloat { get }

    func setTabsMode(_ mode: TabsMode)
    func setDefaultTab(_ tab: CustomTab)
    func reloadTabsMode()
    func rememberSelectedTab(_ tab: CustomTab)
    func restoreSelectedTab() -> CustomTab
    func bottomInset(base: CGFloat, isPlayerVisible: Bool, isPlaying: Bool) -> CGFloat
}
