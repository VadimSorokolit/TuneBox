//
//  Theme+Extensions.swift
//  TuneBox
//
//  Created by Nintendo on 01.06.2026.
//

import SwiftUI

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

private struct ApplyThemeModifier: ViewModifier {
    let manager: ThemeManager

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(manager.forcedColorScheme)
            .background {
                ThemeSchemeSyncView(manager: manager)
            }
    }
}

private struct ThemeSchemeSyncView: View {
    let manager: ThemeManager

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Color.clear
            .onChange(of: scheme, initial: true) { _, newScheme in
                manager.syncSystemScheme(manager.forcedColorScheme ?? newScheme)
            }
            .onChange(of: manager.preset) { _, _ in
                manager.syncSystemScheme(manager.forcedColorScheme ?? scheme)
            }
    }
}

extension View {

    func applyThemeBackground(_ theme: ThemeManager) -> some View {
        Group {
            if let name = theme.tokens.backgroundImageName {
                Image(name)
                    .resizable()
                    .scaledToFill()
            } else {
                theme.tokens.appBackground
            }
        }
        .ignoresSafeArea()
    }

    func applyTheme(_ manager: ThemeManager) -> some View {
        self.modifier(ApplyThemeModifier(manager: manager))
    }

}

extension EnvironmentValues {

    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }

}
