//
//  RootTabsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 05.06.2026.
//

import SwiftUI
import Resolver

private enum Constants {
    enum Title {
        static let defaultNavigationTitle = "Tracks"
    }

    enum Icons {
        enum Browse {
            static let inactive = "magnifyingglass.circle"
            static let active = "magnifyingglass.circle.fill"
        }

        enum Downloads {
            static let inactive = "arrow.down.circle"
            static let active = "arrow.down.circle.fill"
        }

        enum ImportFiles {
            static let inactive = "folder.circle"
            static let active = "folder.circle.fill"
        }

        enum Settings {
            static let inactive = "gear.circle"
            static let active = "gear.circle.fill"
        }
    }
}

enum TabsMode: String {
    case allTabs
    case `import`
}

enum CustomTab: String, Hashable, Identifiable, CaseIterable {
    case browse
    case downloads
    case importFiles
    case settings

    var id: Self { self }

    var iconInactive: String {
        switch self {
            case .browse:
                Constants.Icons.Browse.inactive

            case .downloads:
                Constants.Icons.Downloads.inactive

            case .importFiles:
                Constants.Icons.ImportFiles.inactive

            case .settings:
                Constants.Icons.Settings.inactive
        }
    }

    var iconActive: String {
        switch self {
            case .browse:
                Constants.Icons.Browse.active

            case .downloads:
                Constants.Icons.Downloads.active

            case .importFiles:
                Constants.Icons.ImportFiles.active

            case .settings:
                Constants.Icons.Settings.active
        }
    }
}

struct RootTabsView: View {

    // MARK: - Main Body

    var body: some View {
        ZStack(alignment: .bottom) {
            content

            if playerViewModel.isPlayerVisible {
                CompactPlayerView(
                    track: playerViewModel.track,
                    isPlaying: playerViewModel.isPlaying,
                    progress: playerViewModel.progress,
                    repeatMode: playerViewModel.repeatMode,
                    isShuffleEnabled: playerViewModel.isShuffleEnabled,
                    onTrackInfoTap: {
                        openTrackSource()
                    },
                    onSeek: { delta in
                        playerViewModel.seek(by: delta)
                    },
                    onSeekHoldChanged: { isHolding in
                        playerViewModel.setSeekScrubbing(isHolding)
                    },
                    onPlayPauseTap: {
                        playerViewModel.togglePlayPause()
                    },
                    onProgressTap: {
                        isShowingExpandedPlayer = true
                    },
                    onRepeatModeChange: { mode in
                        playerViewModel.setRepeatMode(mode)
                    },
                    onShuffleToggle: {
                        playerViewModel.toggleShuffle()
                    }
                )
                .padding(.bottom, rootTabsViewModel.isTabBarVisible ? rootTabsViewModel.tabBarHeight : 0)
            }

            if rootTabsViewModel.isTabBarVisible {
                tabBar
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isShowingExpandedPlayer) {
            Text("Expanded player")
        }
        .animation(.easeInOut(duration: 0.25), value: isShowingExpandedPlayer)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            restoreSelectedTab()
            playerViewModel.restoreLastPlaybackSession()
        }
        .task {
            playerViewModel.restoreLastPlaybackSession()
        }
        .onChange(of: rootTabsViewModel.tabsMode) { _, _ in
            restoreSelectedTab()
        }
        .onChange(of: coordinator.selectedTab) { _, newTab in
            rootTabsViewModel.rememberSelectedTab(newTab)
        }
    }

    // MARK: - Properties. Private

    @Injected private var rootTabsViewModel: RootTabsManaging
    @Injected private var playerViewModel: PlayerManaging
    @Environment(\.themeManager) private var theme
    @Environment(AppCoordinator.self) private var coordinator
    @State private var isShowingExpandedPlayer: Bool = false

    private var content: some View {
        Group {
            switch coordinator.selectedTab {
                case .browse:
                    BrowseView()

                case .downloads:
                    DownloadsView()

                case .importFiles:
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

                                    case .tracks(let title, let content):
                                        TracksView(
                                            navigationTitle: title ?? Constants.Title.defaultNavigationTitle,
                                            content: content
                                        )

                                    case .playlists:
                                        PlaylistsView()

                                    case .sourceFolder(let sourceID, let path):
                                        SourceView(sourceID: sourceID, path: path)

                                    default: EmptyView()
                                }
                            }
                    }

                case .settings:
                    SettingsView()
            }
        }
    }

    private var tabBar: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 10) {
                ForEach(rootTabsViewModel.visibleTabs) { tab in
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
        }
        .padding(.horizontal, 6)
        .frame(height: rootTabsViewModel.tabBarHeight)
        .background(tabBarBackground)
    }

    private var tabBarBackground: some View {
        Rectangle()
            .foregroundStyle(theme.tokens.tabBarBackground)
            .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Private. Methods

    private func restoreSelectedTab() {
        coordinator.selectedTab = rootTabsViewModel.restoreSelectedTab()
    }

    private func openTrackSource() {
        if playerViewModel.playbackNavigationPath.isEmpty {
            playerViewModel.refreshPlaybackNavigationPath(library: nil)
        }

        let path = playerViewModel.playbackNavigationPath
        guard path.isNotEmpty else { return }

        coordinator.switchToTab(.importFiles)
        coordinator.syncPath(path)
    }

    // MARK: - Private. Object

    fileprivate struct TabItemView: View {

        // MARK: - Properties. Public

        fileprivate let tab: CustomTab
        fileprivate let isSelected: Bool
        fileprivate let activeColor: Color
        fileprivate let inactiveColor: Color
        fileprivate let onTap: () -> Void

        // MARK: - Main Body

        var body: some View {
            Button(
                action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        onTap()
                    }
                },
                label: {
                    Image(systemName: isSelected ? tab.iconActive : tab.iconInactive)
                        .font(.system(size: 30, weight: .ultraLight))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? activeColor : inactiveColor)
                        .frame(
                            width: isSelected ? iconWidth + 5 : iconWidth,
                            height: isSelected ? iconWidth + 5 : iconWidth
                        )
                        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isSelected)
                        .frame(maxWidth: .infinity)
                }
            )
            .offset(y: 10)
            .buttonStyle(.plain)
        }

        // MARK: - Properties. Private

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
