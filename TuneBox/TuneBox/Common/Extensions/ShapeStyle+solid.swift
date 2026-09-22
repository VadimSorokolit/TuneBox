//
//  ShapeStyle+solid.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 22.09.2026.
//

import SwiftUI

extension ShapeStyle where Self == LinearGradient {

    static func solid(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color], startPoint: .leading, endPoint: .trailing)
    }

}
