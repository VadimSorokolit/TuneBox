//
//  TabHeaderView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.09.2026.
//

import SwiftUI
import Resolver

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

            HStack(spacing: 8) {
                trailing

                // Keep trailing actions clear of the root sleep-timer overlay.
                if settingsVM.isSleepTimerActive {
                    Color.clear
                        .frame(size: GlobalConstants.HeaderButton.size)
                }
            }
        }
        .padding(.horizontal, GlobalConstants.Screen.horizontalInset)
    }

    // MARK: - Properties. Private

    @Environment(\.themeManager) private var theme
    @Injected private var settingsVM: SettingsManaging

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
