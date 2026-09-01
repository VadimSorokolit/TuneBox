//
//  SettingsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import Resolver
import SwiftUI

struct SettingsView: View {

    var body: some View {
        List {
            #if DEBUG
            trialDebugSection
            #endif
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
    }

    #if DEBUG

    // MARK: - Properties. Private

    @Injected private var settingsVM: SettingsManaging
    @Environment(\.themeManager) private var theme

    // MARK: - Subviews. Private

    private var trialDebugSection: some View {
        Section("Trial Debug") {
            LabeledContent("Premium") {
                Text(settingsVM.hasPremium ? "Yes" : "No")
            }

            LabeledContent("Trial") {
                Text(trialStatusText)
            }

            Text(settingsVM.paywallStatusMessage)
                .font(.footnote)
                .foregroundStyle(theme.tokens.secondaryText)

            Button("Expire Trial") {
                settingsVM.debugExpireTrial()
            }

            Button("Reset Trial") {
                settingsVM.debugResetTrial()
            }

            Button("Show Paywall") {
                settingsVM.presentPaywall()
            }
        }
    }

    private var trialStatusText: String {
        switch settingsVM.localTrialStatus {
            case .active(until: let endDate):
                "Active until \(endDate.formatted(date: .abbreviated, time: .omitted))"
            case .expired(since: let endDate):
                "Expired since \(endDate.formatted(date: .abbreviated, time: .omitted))"
            case nil:
                "Not started"
        }
    }

    #else

    // MARK: - Properties. Private

    @Environment(\.themeManager) private var theme

    #endif
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(\.themeManager, ThemeManager())
}
