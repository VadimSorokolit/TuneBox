//
//  HeaderGlassButton.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 17.09.2026.
//

import SwiftUI

struct HeaderGlassButton: View {

    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(GlobalConstants.HeaderButton.font)
            .foregroundStyle(GlobalConstants.HeaderButton.foregroundStyle)
            .frame(size: GlobalConstants.HeaderButton.size)
            .contentShape(Circle())
            .glassEffect(in: .circle)
    }

}

#Preview {
    HeaderGlassButton(systemName: "ellipsis")
}
