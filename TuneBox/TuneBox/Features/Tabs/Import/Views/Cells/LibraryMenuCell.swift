//
//  FolderCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI

struct LibraryMenuCell: View {

    // MARK: - Properties. Public

    let item: ImportItem
    let onTapGesture: () -> Void

    // MARK: - Body

    var body: some View {
        HStack {
            switch item {
                case .library(let libraryItem):
                    VStack(spacing: 15) {
                        HStack(spacing: 10) {
                            Image(systemName: libraryItem.systemImage)
                                .foregroundStyle(.gray)
                                .font(.system(size: 22, weight: .medium))
                                .frame(width: 22, height: 22)

                            Text(libraryItem.rawValue.capitalized)
                                .font(.system(size: 18, weight: .regular))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 26)

                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                            .padding(.leading, 58)
                            .padding(.trailing, 26)
                    }
                    .padding(.top, 15)

                case .source:
                    Text("Source")

                case .addSource(let sourceKind):
                    Text(sourceKind.addTitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onTapGesture {
            onTapGesture()
        }
    }
}

#Preview {
    LibraryMenuCell(
        item: .library(.artists),
        onTapGesture: {}
    )
}
