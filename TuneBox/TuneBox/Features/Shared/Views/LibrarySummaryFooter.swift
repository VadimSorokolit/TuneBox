//
//  LibrarySummaryFooter.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 22.07.2026.
//

import SwiftUI

struct LibrarySummaryFooter: View {
    let count: Int
    let unitSingular: String
    let unitPlural: String
    let duration: Int
    let size: Int
    var topPadding: CGFloat = 0

    var body: some View {
        Text(
            "\(count) \(count == 1 ? unitSingular : unitPlural) · "
            + "\(duration.formattedDuration) · "
            + "\(size.formattedFileSize)"
        )
        .padding(.top, topPadding)
        .multilineTextAlignment(.center)
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(.gray)
    }
}
