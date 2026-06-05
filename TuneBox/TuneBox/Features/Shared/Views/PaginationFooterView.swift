//
//  PaginationFooterView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 05.06.2026.
//

import SwiftUI

struct PaginationFooterView: View {
    enum Style {
        case list
        case carousel
    }

    let hasReachedEnd: Bool
    let hasItems: Bool
    var style: Style = .list

    var body: some View {
        if hasItems && hasReachedEnd {
            endView
        }
    }

    @ViewBuilder
    private var endView: some View {
        switch style {
            case .list:
                Text("No more tracks")
                    .font(.satoshi.medium.size(13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)

            case .carousel:
                VStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 20, weight: .light))

                    Text("No more tracks")
                        .font(.satoshi.medium.size(12))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .frame(width: 100, height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }
}

#Preview("Carousel") {
    PaginationFooterView(
        hasReachedEnd: true,
        hasItems: true,
        style: .carousel
    )
}
