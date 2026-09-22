//
//  Presenter.swift
//  TuneBox
//
//  Created by Presenter on 22.09.2026.
//

import UIKit

final class Presenter: UIViewController {

    // MARK: - Properties. Public

    var onDidAppear: ((Presenter) -> Void)?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .clear
        self.view.isUserInteractionEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.onDidAppear?(self)
    }
}
