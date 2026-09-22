//
//  View+customNavigationTitle.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 28.08.2026.
//

import SwiftUI
import UIKit

extension View {

    func customNavigationTitle(
        _ title: String,
        lineLimit: Int = 2
    ) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(lineLimit)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
    }

    func libraryMenuNavigationTitle(_ title: String) -> some View {
        navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
    }

    func importHomeNavigationChrome() -> some View {
        navigationBarBackButtonHidden(true)
            .toolbarTitleDisplayMode(.inline)
            .background {
                ImportHomeNavigationLock()
            }
    }

}

private struct ImportHomeNavigationLock: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> Host {
        Host()
    }

    func updateUIViewController(_ uiViewController: Host, context: Context) {
        uiViewController.syncToVisibility()
    }

    final class Host: UIViewController {

        private var isHomeVisible = false
        private var isLeavingHome = false
        private var isInteractivePopUnderway = false
        private var didHideBackButton = false
        private var didHideChrome = false
        private var hiddenChrome: [ChromeRef] = []
        private var displayLink: CADisplayLink?
        private var scrubUntil: CFTimeInterval = 0

        deinit {
            displayLink?.invalidate()
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            // An edge swipe pops back onto Home while the screen above is still
            // showing its back button. Hiding chrome in that window strips the
            // chevron and leaves the button untappable after the swipe cancels.
            let coordinator = transitionCoordinator
            isInteractivePopUnderway = coordinator?.isInteractive == true
                || coordinator?.initiallyInteractive == true
            isLeavingHome = false
            isHomeVisible = true

            transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
                self?.lockIfHomeIsTop()
            }, completion: { [weak self] context in
                guard let self else { return }
                self.isInteractivePopUnderway = false
                if context.isCancelled {
                    self.isLeavingHome = true
                    self.isHomeVisible = false
                    self.unlock()
                } else {
                    self.lockIfHomeIsTop()
                    self.startScrubbing()
                }
            })
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard isEdgeSwipeActive.isFalse else { return }

            isLeavingHome = false
            isHomeVisible = true
            lockIfHomeIsTop()
            startScrubbing()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            lockIfHomeIsTop()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            isInteractivePopUnderway = false
            isLeavingHome = true
            isHomeVisible = false
            unlock()
        }

        func syncToVisibility() {
            if isLeavingHome {
                unlock()
                return
            }

            lockIfHomeIsTop()
        }

        private func startScrubbing() {
            guard isEdgeSwipeActive.isFalse, isLeavingHome.isFalse, isHomeVisible, isHomeTheTopItem else { return }

            scrubUntil = CACurrentMediaTime() + 1.0
            guard displayLink == nil else { return }

            let link = CADisplayLink(target: self, selector: #selector(scrubFrame))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        private func stopScrubbing() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func scrubFrame() {
            lockIfHomeIsTop()
            guard CACurrentMediaTime() >= scrubUntil else { return }
            stopScrubbing()
        }

        private func lockIfHomeIsTop() {
            if isEdgeSwipeActive {
                return
            }

            guard isLeavingHome.isFalse, isHomeVisible, isHomeTheTopItem else { return }

            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            navigationItem.hidesBackButton = true
            navigationItem.title = nil
            navigationItem.largeTitleDisplayMode = .never
            nearestNavigationItem?.hidesBackButton = true
            nearestNavigationItem?.title = nil
            nearestNavigationItem?.largeTitleDisplayMode = .never
            didHideBackButton = true
            setBackChromeHidden(true)
        }

        private func unlock() {
            stopScrubbing()

            // A cancelled edge swipe still owns the back button. Toggling
            // hidesBackButton or alpha here drops the chevron and kills the tap.
            guard isEdgeSwipeActive.isFalse else { return }

            navigationController?.interactivePopGestureRecognizer?.isEnabled = true

            if didHideBackButton {
                didHideBackButton = false
                navigationItem.hidesBackButton = false
                nearestNavigationItem?.hidesBackButton = false
            }

            guard didHideChrome else { return }
            restoreHiddenChrome()
        }

        private var isEdgeSwipeActive: Bool {
            if isInteractivePopUnderway { return true }

            switch navigationController?.interactivePopGestureRecognizer?.state {
                case .began, .changed:
                    return true
                default:
                    return false
            }
        }

        private func setBackChromeHidden(_ hidden: Bool) {
            guard hidden, let bar = navigationController?.navigationBar else { return }

            hiddenChrome.removeAll()
            hideBackChrome(in: bar)
            didHideChrome = hiddenChrome.isEmpty.isFalse
        }

        private func restoreHiddenChrome() {
            didHideChrome = false
            hiddenChrome.forEach { ref in
                guard let view = ref.view else { return }
                view.isHidden = false
                view.alpha = 1
                view.isUserInteractionEnabled = true
            }
            hiddenChrome.removeAll()
        }

        private func hideBackChrome(in view: UIView) {
            if isLeftoverHomeChrome(view) {
                // Kill leftover glass only while Home is settled on top.
                view.layer.removeAllAnimations()
                view.layer.sublayers?.forEach { $0.removeAllAnimations() }
                view.isHidden = true
                view.alpha = 0
                view.isUserInteractionEnabled = false
                hiddenChrome.append(ChromeRef(view))
            }

            view.subviews.forEach { hideBackChrome(in: $0) }
        }

        private final class ChromeRef {
            weak var view: UIView?

            init(_ view: UIView) {
                self.view = view
            }
        }

        private func isLeftoverHomeChrome(_ view: UIView) -> Bool {
            let name = NSStringFromClass(type(of: view))
            let isTitleChrome =
                name.contains("TitleControl")
                || name.contains("NavigationBarTitle")

            if isTitleChrome {
                return true
            }

            let isButtonChrome =
                name.contains("PlatterGlass")
                || name.contains("BarPlatter")
                || name.contains("BackButton")
                || name.contains("UIButtonBarButton")

            guard isButtonChrome else { return false }
            guard view.bounds.width < 160 else { return false }
            guard let bar = navigationController?.navigationBar else { return false }

            // Only hide leftover leading back chrome. The trailing menu
            // lives in the same bar and must stay visible.
            let frame = view.convert(view.bounds, to: bar)
            return frame.maxX < bar.bounds.midX
        }

        private var isHomeTheTopItem: Bool {
            guard let navigationController else { return false }

            if let homeItem = nearestNavigationItem,
               let topItem = navigationController.topViewController?.navigationItem,
               homeItem === topItem {
                return true
            }

            var current: UIViewController? = self
            while let controller = current {
                if controller === navigationController.topViewController {
                    return true
                }
                current = controller.parent
            }

            return false
        }

        private var nearestNavigationItem: UINavigationItem? {
            sequence(first: self as UIViewController, next: \.parent)
                .first { $0.parent is UINavigationController }?
                .navigationItem
        }
    }

}
