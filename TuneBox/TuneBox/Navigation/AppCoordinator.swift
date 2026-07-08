//
//  AppCoordinator.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.07.2026.
//

import SwiftUI
import Observation
import os

@MainActor
@Observable
final class AppCoordinator {

    // MARK: - Types

    private enum NavigationAction: String {
        case setRoot
        case push
        case pop
        case popToRoot
        case popTo
        case replaceTop
        case present
        case dismiss
        case switchTab
        case syncPath
    }

    // MARK: - Root

    private(set) var root: AppRoute

    // MARK: - Tabs

    var selectedTab: CustomTab = .browse

    // MARK: - Navigation

    private(set) var path: [AppRoute] = []

    // MARK: - Presentation

    private(set) var presentedSheet: AppRoute?
    private(set) var presentedFullScreen: AppRoute?

    // MARK: - State

    var currentRoute: AppRoute {
        self.path.last ?? root
    }

    var canPop: Bool {
        !self.path.isEmpty
    }

    var stackDepth: Int {
        self.path.count
    }

    var isMainActive: Bool {
        self.root == .main
    }

    var isPresenting: Bool {
        self.presentedSheet != nil || self.presentedFullScreen != nil
    }

    // MARK: - Private

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "TuneBox",
        category: "Navigation"
    )

    // MARK: - Init

    init(root: AppRoute = .launch) {
        self.root = root

        if root == .main {
            self.selectedTab = .browse
        }
    }

    // MARK: - Root

    func setRoot(
        _ route: AppRoute,
        animated: Bool = true
    ) {
        self.perform(animated: animated) {
            self.root = route
            self.path.removeAll()
            self.presentedSheet = nil
            self.presentedFullScreen = nil

            if route == .main {
                self.selectedTab = .browse
            }
        }

        self.log(.setRoot, route)
    }

    // MARK: - Tabs

    func switchToTab(
        _ tab: CustomTab,
        animated: Bool = true
    ) {
        guard self.isMainActive else {
            Self.logger.warning("Ignored switchToTab(\(String(describing: tab)))")
            return
        }

        guard self.selectedTab != tab else {
            Self.logger.debug("Already selected \(String(describing: tab))")

            return
        }

        let action = {
            self.selectedTab = tab
        }

        if animated {
            withAnimation(
                .spring(response: 0.28, dampingFraction: 0.78),
                action
            )
        } else {
            action()
        }

        self.log(.switchTab, self.root, note: String(describing: tab))
    }

    // MARK: - Push

    @discardableResult
    func push(
        _ route: AppRoute,
        animated: Bool = true
    ) -> Bool {
        guard self.canPush(route) else {
            return false
        }

        self.perform(animated: animated) {
            self.path.append(route)
        }

        self.log(.push, route)

        return true
    }

    // MARK: - Pop

    @discardableResult
    func pop(animated: Bool = true) -> Bool {
        guard self.canPop else {
            Self.logger.debug("Ignored pop — stack is empty")

            return false
        }

        let route = self.currentRoute

        self.perform(animated: animated) {
            self.path.removeLast()
        }

        self.log(.pop, route)

        return true
    }

    func popToRoot(animated: Bool = true) {
        guard self.canPop else { return }

        self.perform(animated: animated) {
            self.path.removeAll()
        }

        self.log(.popToRoot, root)
    }

    func pop(
        to route: AppRoute,
        animated: Bool = true
    ) {
        guard route != self.root else {
            self.popToRoot(animated: animated)

            return
        }

        guard let index = self.path.lastIndex(of: route) else {
            Self.logger.warning("\(String(describing: route)) not found in stack")
            return
        }

        let removeCount = self.path.count - index - 1
        guard removeCount > 0 else { return }

        self.perform(animated: animated) {
            self.path.removeLast(removeCount)
        }

        self.log(.popTo, route, note: "removed \(removeCount)")
    }

    // MARK: - Replace

    @discardableResult
    func replaceTop(
        with route: AppRoute,
        animated: Bool = true
    ) -> Bool {
        guard self.canPop else {
            Self.logger.warning("ReplaceTop called on empty stack")
            return false
        }

        guard self.canPush(route) else {
            return false
        }

        self.perform(animated: animated) {
            self.path.removeLast()
            self.path.append(route)
        }

        self.log(.replaceTop, route)
        return true
    }

    // MARK: - NavigationStack sync

    func syncPath(_ newPath: [AppRoute]) {
        guard path != newPath else { return }

        self.path = newPath
        self.log(.syncPath, currentRoute, note: "depth=\(path.count)")
    }

    var pathBinding: Binding<[AppRoute]> {
        Binding(
            get: {
                self.path
            },
            set: {
                self.syncPath($0)
            }
        )
    }

    // MARK: - Presentation

    func presentSheet(_ route: AppRoute) {
        self.presentedSheet = route
        self.log(.present, route, note: "sheet")
    }

    func presentFullScreen(_ route: AppRoute) {
        self.presentedFullScreen = route
        self.log(.present, route, note: "fullScreen")
    }

    func dismissPresented() {
        let route = self.presentedSheet ?? self.presentedFullScreen
        self.presentedSheet = nil
        self.presentedFullScreen = nil

        guard let route else {
            return
        }
        self.log(.dismiss, route)
    }

    // MARK: - Query

    func contains(_ route: AppRoute) -> Bool {
        self.root == route || self.path.contains(route)
    }
}

// MARK: - Private

private extension AppCoordinator {

    func canPush(_ route: AppRoute) -> Bool {
        if route == .launch
            || route == .onboarding
            || route == .main {

            Self.logger.warning("Use setRoot instead of push")

            return false
        }

        guard self.currentRoute != route else {
            Self.logger.debug("Ignored duplicate push of \(String(describing: route))")
            return false
        }

        return true
    }

    func perform(
        animated: Bool,
        _ action: @escaping () -> Void
    ) {
        guard animated else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, action)
            return
        }

        action()
    }

    private func log(
        _ action: NavigationAction,
        _ route: AppRoute,
        note: String? = nil
    ) {
        var message = "[\(action.rawValue.uppercased())] \(String(describing: route))"
        message += " depth=\(path.count)"

        if let note {
            message += " [\(note)]"
        }

        Self.logger.debug("\(message)")
    }

}
