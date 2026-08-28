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
    
}
