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
                        .font(.satoshi.bold.size(17))
                        .lineLimit(lineLimit)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
    }

    func importHomeNavigationChrome(isHomeTop: Bool) -> some View {
        navigationBarBackButtonHidden(isHomeTop)
            .toolbarTitleDisplayMode(.inline)
            .background {
                ImportHomeNavigationLock(isHomeTop: isHomeTop)
            }
    }

}

private struct ImportHomeNavigationLock: UIViewControllerRepresentable {

    let isHomeTop: Bool

    func makeUIViewController(context: Context) -> Host {
        Host()
    }

    func updateUIViewController(_ uiViewController: Host, context: Context) {
        uiViewController.apply(isHomeTop: isHomeTop)
    }

    final class Host: UIViewController {

        private var isHomeTop = true

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply(isHomeTop: isHomeTop)
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply(isHomeTop: isHomeTop)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            // Always reveal the bar before a child settles so its back button
            // can receive taps.
            revealBarForChild()
        }

        func apply(isHomeTop: Bool) {
            self.isHomeTop = isHomeTop

            if isHomeTop {
                lockHomeBar()
            } else {
                revealBarForChild()
            }
        }

        private func lockHomeBar() {
            guard isHomeTheTopItem else {
                revealBarForChild()
                return
            }

            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            navigationController?.navigationBar.prefersLargeTitles = false

            if navigationController?.isNavigationBarHidden == false {
                navigationController?.setNavigationBarHidden(true, animated: false)
            }
        }

        private func revealBarForChild() {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true

            if navigationController?.isNavigationBarHidden == true {
                navigationController?.setNavigationBarHidden(false, animated: false)
            }
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
