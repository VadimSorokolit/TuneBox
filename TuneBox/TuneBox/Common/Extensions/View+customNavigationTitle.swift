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
            isLeavingHome = false
            isHomeVisible = true
            transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
                self?.lockIfHomeIsTop()
            }, completion: { [weak self] context in
                guard let self else { return }
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
            guard isLeavingHome.isFalse, isHomeVisible, isHomeTheTopItem else { return }

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
            guard isLeavingHome.isFalse, isHomeVisible, isHomeTheTopItem else { return }

            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            navigationItem.hidesBackButton = true
            navigationItem.title = nil
            navigationItem.largeTitleDisplayMode = .never
            nearestNavigationItem?.hidesBackButton = true
            nearestNavigationItem?.title = nil
            nearestNavigationItem?.largeTitleDisplayMode = .never
            setBackChromeHidden(true)
        }

        private func unlock() {
            stopScrubbing()
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            navigationItem.hidesBackButton = false
            nearestNavigationItem?.hidesBackButton = false
            setBackChromeHidden(false)
        }

        private func setBackChromeHidden(_ hidden: Bool) {
            guard let bar = navigationController?.navigationBar else { return }
            applyBackChromeHidden(hidden, in: bar)
        }

        private func applyBackChromeHidden(_ hidden: Bool, in view: UIView) {
            if isLeftoverHomeChrome(view) {
                // Kill leftover glass only while hiding on Home.
                // Restoring must keep the incoming back-button animation intact,
                // otherwise the chevron never draws and the tap does not pop.
                if hidden {
                    view.layer.removeAllAnimations()
                    view.layer.sublayers?.forEach { $0.removeAllAnimations() }
                }
                view.isHidden = hidden
                view.alpha = hidden ? 0 : 1
                view.isUserInteractionEnabled = !hidden
            }

            view.subviews.forEach { applyBackChromeHidden(hidden, in: $0) }
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
