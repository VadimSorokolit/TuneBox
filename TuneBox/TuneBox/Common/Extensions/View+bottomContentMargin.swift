//
//  View+bottomContentMargin.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 28.07.2026.
//

import SwiftUI

extension View {

    func bottomContentMargin(_ value: CGFloat = 40) -> some View {
        contentMargins(.bottom, value)
    }

}
