//
//  SheetHost.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 22.09.2026.
//

import SwiftUI

final class SheetHost<RootView: View>: UIHostingController<RootView> {
    var onDidDismiss: (() -> Void)?
    private var didAppear = false
    private var isDismissing = false
    private var didNotifyDismiss = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.didAppear = true
        self.isDismissing = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isBeingDismissed {
            self.isDismissing = true
        }
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag) { [weak self] in
            completion?()
            self?.notifyDismissed()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard self.didAppear, self.isDismissing else { return }

        self.notifyDismissed()
    }

    private func notifyDismissed() {
        guard self.didNotifyDismiss.isFalse else { return }

        self.didNotifyDismiss = true
        self.onDidDismiss?()
    }
}
