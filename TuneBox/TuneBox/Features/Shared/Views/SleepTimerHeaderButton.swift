//
//  SleepTimerHeaderButton.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 29.09.2026.
//

import SwiftUI
import Resolver

struct SleepTimerHeaderButton: View {

    // MARK: - Main Body

    var body: some View {
        Group {
            if settingsVM.isSleepTimerActive {
                Button {
                    isPresented = true
                } label: {
                    activeLabel
                }
                .headerGlassChrome()
                .accessibilityLabel(L10n.Settings.sleepTimer)
                .accessibilityValue(settingsVM.sleepTimerTrailingText)
                .transition(.opacity)
                .sheet(isPresented: $isPresented) {
                    SleepTimerSheetView(settingsVM: settingsVM) {
                        isPresented = false
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: settingsVM.isSleepTimerActive)
    }

    // MARK: - Properties. Private

    @Environment(\.themeManager) private var theme
    @Injected private var settingsVM: SettingsManaging
    @State private var isPresented = false

    private var activeLabel: some View {
        let size = GlobalConstants.HeaderButton.size
        let lineWidth = GlobalConstants.ProgressRing.lineWidth
        let ringInset: CGFloat = 1
        let progress = settingsVM.sleepTimerProgress

        return ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
                .padding(ringInset)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(ringInset)
                .animation(.linear(duration: 0.25), value: progress)

            Image(systemName: "timer")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(labelColor)
        }
        .frame(size: size)
        .contentShape(Circle())
    }

    private var labelColor: Color {
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

    private var progressColor: Color {
        switch theme.preset {
            case .light:
                theme.tokens.accent

            case .dark:
                Color(hex: 0x7EBF96)

            case .system:
                theme.systemColorScheme == .dark
                    ? Color(hex: 0x7EBF96)
                    : theme.tokens.accent
        }
    }

    private var trackColor: Color {
        progressColor.opacity(0.22)
    }
}

#Preview {
    HStack(spacing: 16) {
        SleepTimerHeaderButton()
    }
    .padding()
}
