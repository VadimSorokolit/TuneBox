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
            .foregroundStyle(iconColor)
            .frame(size: GlobalConstants.HeaderButton.size)
            .contentShape(Circle())
    }

    // MARK: - Properties. Private

    @Environment(\.themeManager) private var theme

    private var iconColor: Color {
        switch theme.preset {
            case .light:
                GlobalConstants.HeaderButton.foregroundStyle

            case .dark:
                theme.tokens.browseHeaderText

            case .system:
                theme.systemColorScheme == .dark
                    ? theme.tokens.browseHeaderText
                    : GlobalConstants.HeaderButton.foregroundStyle
        }
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
