//
//  SpinnerView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import SwiftUI

struct SpinnerView: View {
    let isLoading: Bool

    var body: some View {
        if isLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.gray)
                .controlSize(.large)
                .background(Color.clear)
        }
    }

}
