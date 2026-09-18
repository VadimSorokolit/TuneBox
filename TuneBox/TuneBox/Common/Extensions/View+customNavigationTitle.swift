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
        uiViewController.lock()
    }

    final class Host: UIViewController {

        private var isHomeVisible = false
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
            isHomeVisible = true
            lock()
            startScrubbing()
            transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
                self?.lock()
            }, completion: { [weak self] context in
                guard let self else { return }
                if context.isCancelled {
                    self.isHomeVisible = false
                    self.stopScrubbing()
                    self.setBackChromeHidden(false)
                } else {
                    self.lock()
                    self.startScrubbing()
                }
            })
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            isHomeVisible = true
            lock()
            startScrubbing()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            guard isHomeVisible else { return }
            lock()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            isHomeVisible = false
            stopScrubbing()
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            setBackChromeHidden(false)
        }

        private func startScrubbing() {
            scrubUntil = CACurrentMediaTime() + 0.55
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
            lock()
            guard CACurrentMediaTime() >= scrubUntil else { return }
            stopScrubbing()
        }

        func lock() {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            navigationItem.hidesBackButton = true
            nearestNavigationItem?.hidesBackButton = true
            setBackChromeHidden(true)
        }

        private func setBackChromeHidden(_ hidden: Bool) {
            guard let bar = navigationController?.navigationBar else { return }
            applyBackChromeHidden(hidden, in: bar)
        }

        private func applyBackChromeHidden(_ hidden: Bool, in view: UIView) {
            if isLeftoverBackChrome(view) {
                view.layer.removeAllAnimations()
                view.layer.sublayers?.forEach { $0.removeAllAnimations() }
                view.isHidden = hidden
                view.alpha = hidden ? 0 : 1
            }

            view.subviews.forEach { applyBackChromeHidden(hidden, in: $0) }
        }

        private func isLeftoverBackChrome(_ view: UIView) -> Bool {
            let name = NSStringFromClass(type(of: view))
            let isButtonChrome =
                name.contains("PlatterGlass")
                || name.contains("BarPlatter")
                || name.contains("BackButton")
                || name.contains("UIButtonBarButton")

            guard isButtonChrome else { return false }

            // Home has no bar buttons. Hide compact leftover platters even
            // while they are mid-transition, but keep full-width bar chrome.
            return view.bounds.width < 160
        }

        private var nearestNavigationItem: UINavigationItem? {
            sequence(first: self as UIViewController, next: \.parent)
                .first { $0.parent is UINavigationController }?
                .navigationItem
        }
    }

}
