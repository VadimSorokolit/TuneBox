//
//  CoverCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 11.08.2026.
//

import SwiftUI

struct CoverCell: View {

    // MARK: - Properties. Public

    let coverPath: String
    let size: CGFloat
    let cornerRadius: CGFloat

    // MARK: - Main Body

    var body: some View {
        CoverView(
            coverPath: coverPath,
            size: size,
            cornerRadius: cornerRadius
        )
    }
}
