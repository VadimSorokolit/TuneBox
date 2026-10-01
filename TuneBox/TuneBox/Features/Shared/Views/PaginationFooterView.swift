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
                Text(L10n.Discover.paginationEnd)
                    .font(.satoshi.medium.size(13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                    .padding(.bottom, 10)

            case .carousel:
                ZStack {
                    EmptyGenreCell()

                    VStack(spacing: 6) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 30, weight: .light))

                        Text(L10n.Discover.paginationEnd)
                            .font(.satoshi.medium.size(15))
                            .multilineTextAlignment(.center)
                    }
                }
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
