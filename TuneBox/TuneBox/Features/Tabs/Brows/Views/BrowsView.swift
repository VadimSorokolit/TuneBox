//
//  BrowsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Resolver
import SwiftUI

struct BrowsView: View {

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            SearchView()

            MainView()
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top
        )
    }

    private struct HeaderView: View {
        @Injected var viewModel: TransferManaging
        @Environment(\.themeManager) private var theme

        var body: some View {
            HStack {
                Text("Discover")
                    .foregroundStyle(theme.tokens.browsHeaderText)
                    .font(.satoshiRegular34)

                Spacer()

                Button(action: {
                     viewModel.cancelAllDownloads()
                }, label: {
                    Image(systemName: "xmark.circle")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundColor(viewModel.inProgressTracksCount > .zero
                                         ? theme.tokens.clearAllDownloadsActive
                                         : theme.tokens.clearAllDownloadsInactive
                        )
                })
                .disabled(viewModel.inProgressTracksCount == .zero)
            }
            .padding(.horizontal)
        }

    }

    private struct SearchView: View {

        var body: some View {
            Text("")
                .padding(.top, 10)
        }

    }

    private struct MainView: View {

        var body: some View {
            Text("")

            Spacer()
        }
    }

}

#Preview {
        BrowsView()
}
