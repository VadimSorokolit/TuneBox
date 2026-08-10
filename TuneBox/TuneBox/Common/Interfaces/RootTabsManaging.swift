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
    var visibleTabs: [CustomTab] { get }
    var isTabBarVisible: Bool { get }
    var tabBarHeight: CGFloat { get }
    var playerHeight: CGFloat { get }

    func reloadTabsMode()
    func rememberSelectedTab(_ tab: CustomTab)
    func restoreSelectedTab() -> CustomTab
    func bottomInset(base: CGFloat, isPlayerVisible: Bool) -> CGFloat
}
