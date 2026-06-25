//
//  HighlightedText.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 09.06.2026.
//

import SwiftUI

struct HighlightedText: View {
    let text: String
    let searchQuery: String?

    let highlightColor: Color = Color(hex: 0xFCFAA6)

    var body: some View {
        Text(highlightedAttributedString)
    }

    private var highlightedAttributedString: AttributedString {
        var attributedString = AttributedString(text)

        let query = searchQuery?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard query.isNotEmpty,
              let range = attributedString.range(
                of: query,
                options: .caseInsensitive
              ) else {
            return attributedString
        }

        attributedString[range].backgroundColor = highlightColor

        return attributedString
    }
}
