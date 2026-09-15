//
//  SettingsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.05.2026.
//

import SwiftUI
import Resolver

struct SettingsView: View {
    
    // MARK: - Main Body

    var body: some View {
        Text("Settings view")
    }
    
    // MARK: - Properties. Private

    @Environment(\.themeManager) private var theme
    @Injected private var settingsVM: SettingsManaging
}

#Preview {
    SettingsView()
}
