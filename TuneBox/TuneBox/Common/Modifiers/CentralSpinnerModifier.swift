//
//  CentralSpinnerModifier.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.07.2026.
//

import SwiftUI

struct CentralSpinnerModifier: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isVisible {
                    SpinnerView()
                }
            }
    }
}
