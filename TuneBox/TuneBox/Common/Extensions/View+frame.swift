//
//  View+frame.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 01.07.2026.
//

import SwiftUI

extension View {

    func frame(size: CGFloat) -> some View {
        self.frame(width: size, height: size)
    }

}
