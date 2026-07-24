//
//  GenreCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 05.06.2026.
//

import SwiftUI

enum CustomTab: String, Hashable, Identifiable, CaseIterable {
    case browse
    case downloads
    case importFiles
    case settings

    var id: Self { self }

    var iconInactive: String {
        switch self {
            case .browse:
                "magnifyingglass.circle"

            case .downloads:
                "arrow.down.circle"

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

            case .importFiles:
                "folder.circle.fill"

            case .settings:
                "gear.circle.fill"
        }
    }
}

struct RootTabsView: View {

    // MARK: - Main Body

    var body: some View {
        ZStack(alignment: .bottom) {
            content

            tabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: - Properties. Private

    @Environment(\.themeManager) private var theme
    @Environment(AppCoordinator.self) private var coordinator
    @AppStorage("startTab") private var startTab = CustomTab.browse.rawValue

    private var content: some View {
        TabView(selection: Bindable(coordinator).selectedTab) {
            BrowseView()
                .tag(CustomTab.browse)

            DownloadsView()
                .tag(CustomTab.downloads)

            NavigationStack(path: coordinator.pathBinding) {
                ImportsView()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                            case .albums:
                                AlbumsView()

                            case .album(let album):
                                AlbumDetailsView(album: album)

                            case .artists:
                                ArtistsView()

                            case .artist(artist: let artist):
                                ArtistDetailsView(artist: artist)

                            case .tracks(let title, let tracks):
                                TracksView(navigationTitle: title ?? "Tracks", tracks: tracks)

                            case .playlists:
                                PlaylistsView()

                            case .sourceFolder(let sourceID, let path):
                                SourceView(sourceID: sourceID, path: path)

                            default: EmptyView()
                        }
                    }
            }
            .tag(CustomTab.importFiles)

            SettingsView()
                .tag(CustomTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            coordinator.selectedTab = CustomTab(rawValue: startTab) ?? .browse

        }
    }

    private var tabBar: some View {
        HStack(spacing: 10) {
            ForEach(CustomTab.allCases) { tab in
                TabItemView(
                    tab: tab,
                    isSelected: coordinator.selectedTab == tab,
                    activeColor: theme.tokens.tabIconActive,
                    inactiveColor: theme.tokens.tabIconInactive,
                    onTap: {
                        coordinator.switchToTab(tab)
                    }
                )
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

    // MARK: - Private. Object

    fileprivate struct TabItemView: View {

        // MARK: - Main Body

        var body: some View {
            Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        onTap()
                    }
                },
                label: {
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
            )
            .offset(y: 10)
            .buttonStyle(.plain)
        }

        // MARK: - Properties. Private

        fileprivate let tab: CustomTab
        fileprivate let isSelected: Bool
        fileprivate let activeColor: Color
        fileprivate let inactiveColor: Color
        fileprivate let onTap: () -> Void
        private let iconWidth: CGFloat = 54
    }

}

#Preview("Tab Bar Only") {
    typealias TabItem = RootTabsView.TabItemView

    return ZStack(alignment: .bottom) {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        HStack(spacing: 10) {
            ForEach(CustomTab.allCases) { tab in
                TabItem(
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
