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
            .background {
                NavigationBarTransitionFreeze()
            }
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
            .background {
                NavigationBarTransitionFreeze()
            }
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

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            lock()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            lock()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }

        func lock() {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            navigationItem.hidesBackButton = true
            nearestNavigationItem?.hidesBackButton = true
        }

        private var nearestNavigationItem: UINavigationItem? {
            sequence(first: self as UIViewController, next: \.parent)
                .first { $0.parent is UINavigationController }?
                .navigationItem
        }
    }

}

private struct NavigationBarTransitionFreeze: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> Host {
        Host()
    }

    func updateUIViewController(_ uiViewController: Host, context: Context) {}

    final class Host: UIViewController {

        private var freezeUntil: CFTimeInterval = 0

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            freezeUntil = CACurrentMediaTime() + 0.45
            freezeNavigationBar()
            transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
                self?.freezeNavigationBar()
            })
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            guard CACurrentMediaTime() < freezeUntil else { return }
            freezeNavigationBar()
        }

        private func freezeNavigationBar() {
            guard let bar = navigationController?.navigationBar else { return }
            bar.layer.removeAllAnimations()
            freeze(bar)
        }

        private func freeze(_ view: UIView) {
            view.layer.removeAllAnimations()
            view.layer.sublayers?.forEach { $0.removeAllAnimations() }
            view.subviews.forEach(freeze)
        }
    }

}
