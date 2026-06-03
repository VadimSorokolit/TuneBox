import SwiftUI
import Resolver

enum CustomTab: Hashable, Identifiable, CaseIterable {
    case brows
    case downloads
    case player
    case importFiles
    case settings

    var id: Self { self }

    static let tabs: [CustomTab] = [
        .brows,
        .downloads,
        .player,
        .importFiles,
        .settings
    ]

    var iconInactive: String {
        switch self {
            case .brows:
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
            case .brows:
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
    @Injected private var viewModel: TransferManaging
    @Environment(\.themeManager) private var theme

    var body: some View {
        ZStack(alignment: .bottom) {
            content

            tabBar
        }
        .navigationBarBackButtonHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var content: some View {
        ZStack {
            BrowsView()
                .tabVisible(viewModel.selectedTab == .brows)

            DownloadsView()
                .tabVisible(viewModel.selectedTab == .downloads)

            PlayerView()
                .tabVisible(viewModel.selectedTab == .player)

            ImportFilesView()
                .tabVisible(viewModel.selectedTab == .importFiles)

            SettingsView()
                .tabVisible(viewModel.selectedTab == .settings)
        }
        .ignoresSafeArea(edges: .bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tabBar: some View {
        HStack(spacing: 10) {
            ForEach(CustomTab.tabs) { tab in
                TabItemView(
                    tab: tab,
                    isSelected: viewModel.selectedTab == tab,
                    activeColor: theme.tokens.tabIconActive,
                    inactiveColor: theme.tokens.tabIconInactive
                ) {
                    viewModel.selectedTab = tab
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

private extension View {
    func tabVisible(_ isVisible: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .zIndex(isVisible ? 1 : 0)
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
                    isSelected: tab == .brows,
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
