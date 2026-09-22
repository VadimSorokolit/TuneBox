//
//  ShapeStyle+gradients.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 22.09.2026.
//

import SwiftUI

extension ShapeStyle where Self == LinearGradient {

    static var blackScrim: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0.2),

                Color.black.opacity(0.45),

                Color.black.opacity(0.65)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

}
