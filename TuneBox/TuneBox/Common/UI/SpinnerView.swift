//
//  SpinnerView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import SwiftUI

struct SpinnerView: View {
    var backgroundColor: Color = .clear
    var style: CircularProgressViewStyle = .circular
    var size: ControlSize = .large
    var color: Color = .gray

    var body: some View {
        ProgressView()
            .progressViewStyle(style)
            .tint(color)
            .controlSize(size)
            .background(backgroundColor)
    }

}

#Preview {
    SpinnerView()
}
