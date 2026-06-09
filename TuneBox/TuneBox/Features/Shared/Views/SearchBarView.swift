//
//  SearchBarView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 03.06.2026.
//

import SwiftUI
import Resolver

struct SearchBarView: View {
    @Injected var viewModel: TransferManaging
    @Binding var searchQuery: String
    let isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search...", text: $searchQuery)
                .font(.satoshi.medium.size(14))
                .submitLabel(.search)
                .focused(isFocused)
                .onSubmit {
                    onSubmit()
                }

            if searchQuery.isEmpty == false {
                Button {
                    searchQuery = ""
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
        }
        .padding(.top, 5)
        .padding(.horizontal)
    }
}

#Preview {
    @Previewable @State var searchText = "Love"
    @FocusState var isFocused: Bool

    SearchBarView(
        searchQuery: $searchText,
        isFocused: $isFocused
    ) {
        print("Search:", searchText)
    } onClear: {
        print("Clear")
    }
}
