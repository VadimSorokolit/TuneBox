//
//  View+headerGlassButton.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 17.09.2026.
//

import SwiftUI

extension View {

    func headerGlassButton() -> some View {
        font(GlobalConstants.HeaderButton.font)
            .foregroundStyle(GlobalConstants.HeaderButton.foregroundStyle)
            .frame(size: GlobalConstants.HeaderButton.size)
            .contentShape(Circle())
            .glassEffect(in: .circle)
    }

}
