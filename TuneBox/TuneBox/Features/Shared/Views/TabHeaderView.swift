//
//  TabHeaderView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.09.2026.
//

import SwiftUI

struct TabHeaderView<Trailing: View>: View {

    // MARK: - Properties. Public

    let title: String

    // MARK: - Initializer

    init(
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.trailing = trailing()
    }

    // MARK: - Main Body

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(theme.tokens.browseHeaderText)
                .font(.satoshi.regular.size(34))

            Spacer()

            trailing
        }
        .padding(.horizontal, GlobalConstants.Screen.horizontalInset)
    }

    // MARK: - Properties. Private

    @Environment(\.themeManager) private var theme

    private let trailing: Trailing
}

extension TabHeaderView where Trailing == EmptyView {

    init(title: String) {
        self.init(title: title) {
            EmptyView()
        }
    }
}

#Preview {
    TabHeaderView(title: "Settings")
}
