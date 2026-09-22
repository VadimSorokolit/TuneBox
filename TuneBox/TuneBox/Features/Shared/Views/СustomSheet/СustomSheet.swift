//
//  СustomSheet.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 22.09.2026.
//

import UIKit
import SwiftUI

struct СustomSheet<Content: View>: UIViewControllerRepresentable {

    // MARK: - Properties. Public

    @Binding var isPresented: Bool

    var cornerRadius: CGFloat
    var content: Content

    // MARK: - Initializer

    init(
        isPresented: Binding<Bool>,
        cornerRadius: CGFloat = 40,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    // MARK: - Methods. Public

    func makeCoordinator() -> Coordinator<Content> {
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
}
