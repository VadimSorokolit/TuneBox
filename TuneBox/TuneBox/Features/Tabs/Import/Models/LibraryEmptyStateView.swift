//
//  LibraryEmptyStateView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 30.07.2026.
//

import SwiftUI

struct LibraryEmptyStateView: View {

    // MARK: - Properties. Public

    let item: LibraryItem
    let prefixText: String
    let suffixText: String
    let capitalizeItem: Bool

    // MARK: - Initializer

    init(
        item: LibraryItem,
        prefixText: String = "",
        suffixText: String = "you add to your library will appear here.",
        capitalizeItemText: Bool = true
    ) {
        self.item = item
        self.prefixText = prefixText
        self.suffixText = suffixText
        self.capitalizeItem = capitalizeItemText
    }

    // MARK: - Main Body

    var body: some View {
        ContentUnavailableView {
            Image(systemName: item.systemImage)
                .foregroundStyle(.gray)
                .font(.system(size: imageSize, weight: .bold))
                .frame(size: imageSize)
        } description: {
            Text("\(prefixText) \(itemText) \(suffixText)")
                .padding(.top, 10)
        }
    }

    // MARK: - Properties. Private

    private let imageSize: CGFloat = 30

    private var itemText: String {
        capitalizeItem
            ? item.rawValue.capitalized
            : item.rawValue
    }
}
