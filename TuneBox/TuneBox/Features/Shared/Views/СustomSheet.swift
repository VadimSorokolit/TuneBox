//
//  СustomSheet.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 22.09.2026.
//

import UIKit
import SwiftUI

struct СustomSheet<Content: View>: UIViewControllerRepresentable {

    @Binding var isPresented: Bool
    var cornerRadius: CGFloat
    var content: Content

    init(
        isPresented: Binding<Bool>,
        cornerRadius: CGFloat = 40,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, content: content)
    }

    func makeUIViewController(context: Context) -> Presenter {
        let controller = Presenter()
        controller.onDidAppear = { [weak coordinator = context.coordinator] presenter in
            coordinator?.presentIfNeeded(from: presenter)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: Presenter, context: Context) {
        context.coordinator.content = content
        context.coordinator.cornerRadius = cornerRadius
        context.coordinator.isPresented = $isPresented
        context.coordinator.sync(from: uiViewController, presented: isPresented)
    }

    final class Presenter: UIViewController {
        var onDidAppear: ((Presenter) -> Void)?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onDidAppear?(self)
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var isPresented: Binding<Bool>
        var cornerRadius: CGFloat
        var content: Content
        private var host: UIHostingController<Content>?

        init(isPresented: Binding<Bool>, content: Content) {
            self.isPresented = isPresented
            self.cornerRadius = 40
            self.content = content
        }

        func sync(from presenter: Presenter, presented: Bool) {
            if presented {
                presentIfNeeded(from: presenter)
            } else if let presentedController = presenter.presentedViewController,
                      presentedController.isBeingDismissed.isFalse {
                presenter.dismiss(animated: true)
            }
        }

        func presentIfNeeded(from presenter: Presenter) {
            guard isPresented.wrappedValue else { return }
            guard presenter.view.window != nil else { return }
            guard presenter.presentedViewController == nil else { return }

            let host = UIHostingController(rootView: content)
            host.view.backgroundColor = .clear
            host.modalPresentationStyle = .pageSheet

            if let sheet = host.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.preferredCornerRadius = cornerRadius
                sheet.prefersGrabberVisible = false
            }

            host.presentationController?.delegate = self
            self.host = host
            presenter.present(host, animated: true)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            host = nil
            isPresented.wrappedValue = false
        }
    }
}
