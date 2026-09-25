//
//  HeaderGlassButton.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 17.09.2026.
//

import SwiftUI

struct HeaderGlassButton: View {

    // MARK: - Properties. Public

    let systemName: String

    // MARK: - Main Body

    var body: some View {
        Image(systemName: systemName)
            .font(GlobalConstants.HeaderButton.font)
            .foregroundStyle(GlobalConstants.HeaderButton.foregroundStyle)
            .frame(size: GlobalConstants.HeaderButton.size)
            .contentShape(Circle())
    }

}

extension View {

    func headerGlassChrome() -> some View {
        buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
    }

}

#Preview {
    HeaderGlassButton(systemName: "ellipsis")
        .headerGlassChrome()
}
