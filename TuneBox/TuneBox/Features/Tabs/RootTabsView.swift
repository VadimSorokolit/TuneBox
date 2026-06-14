//
//  GenreCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 05.06.2026.
//

import SwiftUI

enum CustomTab: Hashable, Identifiable, CaseIterable {
    case browse
    case downloads
    case player
    case importFiles
    case settings

    var id: Self { self }

    static let tabs: [CustomTab] = [
        .browse,
        .downloads,
        .player,
        .importFiles,
        .settings
    ]

    var iconInactive: String {
        switch self {
            case .browse:
                "magnifyingglass.circle"
            case .downloads:
                "arrow.down.circle"
            case .player:
                "play.circle"
            case .importFiles:
                "folder.circle"
            case .settings:
                "gear.circle"
        }
    }

    var iconActive: String {
        switch self {
            case .browse:
                "magnifyingglass.circle.fill"
            case .downloads:
                "arrow.down.circle.fill"
            case .player:
                "play.circle.fill"
            case .importFiles:
                "folder.circle.fill"
            case .settings:
                "gear.circle.fill"
        }
    }
}

struct RootTabsView: View {
    @Environment(\.themeManager) private var theme
    @State private var activeTab: CustomTab = .browse

    var body: some View {
        ZStack(alignment: .bottom) {
            content

            tabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch activeTab {
                case .browse:
                    BrowseView()

                case .downloads:
                    DownloadsView()

                case .player:
                    PlayerView()

                case .importFiles:
                    ImportFilesView()

                case .settings:
                    SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
    }

    private var tabBar: some View {
        HStack(spacing: 10) {
            ForEach(CustomTab.tabs) { tab in
                TabItemView(
                    tab: tab,
                    isSelected: activeTab == tab,
                    activeColor: theme.tokens.tabIconActive,
                    inactiveColor: theme.tokens.tabIconInactive
                ) {
                    activeTab = tab
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 60)
        .background(tabBarBackground)
    }

    private var tabBarBackground: some View {
        Rectangle()
            .foregroundStyle(theme.tokens.tabBarBackground)
            .ignoresSafeArea(edges: .bottom)
    }
}

private struct TabItemView: View {
    let tab: CustomTab
    let isSelected: Bool
    let activeColor: Color
    let inactiveColor: Color
    let onTap: () -> Void

    let iconWidth: CGFloat = 54

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                onTap()
            }
        } label: {
            Image(systemName: isSelected ? tab.iconActive : tab.iconInactive)
                .font(.system(size: 30, weight: .ultraLight))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? activeColor : inactiveColor)
                .frame(width: isSelected
                       ? iconWidth + 5
                       : iconWidth,
                       height: isSelected
                       ? iconWidth + 5
                       : iconWidth
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isSelected)
                .frame(maxWidth: .infinity)
        }
        .offset(y: 10)
        .buttonStyle(.plain)
    }
}

#Preview("Tab Bar Only") {
    ZStack(alignment: .bottom) {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        HStack(spacing: 10) {
            ForEach(CustomTab.tabs) { tab in
                TabItemView(
                    tab: tab,
                    isSelected: tab == .browse,
                    activeColor: Color(hex: 0x6B5CFF),
                    inactiveColor: Color.white.opacity(0.45)
                ) {}
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 60)
        .background(.black)
    }
}
