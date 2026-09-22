//
//  Coordinator.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 22.09.2026.
//

import SwiftUI

final class Coordinator<Content: View>: NSObject, UIAdaptivePresentationControllerDelegate {

    // MARK: - Properties. Public

    var isPresented: Binding<Bool>
    var cornerRadius: CGFloat
    var content: Content

    // MARK: - Methods. Public

    func presentIfNeeded(from presenter: Presenter) {
        guard isPresented.wrappedValue else { return }
        guard presenter.view.window != nil else { return }
        guard presenter.presentedViewController == nil else { return }

        let host = SheetHost(rootView: content)
        host.view.backgroundColor = .clear
        host.modalPresentationStyle = .pageSheet
        host.onDidDismiss = { [weak self] in
            self?.handleHostDismissed()
        }

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
        self.handleHostDismissed()
    }

    func sync(from presenter: Presenter, presented: Bool) {
        if presented {
            self.presentIfNeeded(from: presenter)
        } else if let presentedController = presenter.presentedViewController, presentedController.isBeingDismissed.isFalse {
            presenter.dismiss(animated: true)
        }
    }

    // MARK: - Initializer

    init(isPresented: Binding<Bool>, content: Content) {
        self.isPresented = isPresented
        self.cornerRadius = 40
        self.content = content
    }

    // MARK: - Properties. Private

    private var host: SheetHost<Content>?

    // MARK: - Methods. Private

    private func handleHostDismissed() {
        self.host = nil
        guard self.isPresented.wrappedValue else { return }

        self.isPresented.wrappedValue = false
    }
}
