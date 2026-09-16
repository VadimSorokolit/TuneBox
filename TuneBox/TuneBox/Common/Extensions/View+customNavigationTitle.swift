//
//  View+customNavigationTitle.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 28.08.2026.
//

import SwiftUI

extension View {

    func customNavigationTitle(
        _ title: String,
        lineLimit: Int = 2
    ) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(lineLimit)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
    }

    func libraryMenuNavigationTitle(_ title: String) -> some View {
        navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
    }

    func hiddenLibraryNavigationChrome() -> some View {
        navigationTitle("Library")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Library")
                        .font(.headline)
                        .opacity(0)
                        .offset(y: -82)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    }

}
