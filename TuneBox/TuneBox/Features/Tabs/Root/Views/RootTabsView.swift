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
            static let asset = "TabSearch"
        }

        enum Downloads {
            static let asset = "TabDownload"
        }

        enum ImportFiles {
            static let asset = "TabMusic"
        }

        enum Settings {
            static let asset = "TabSettings"
        }
    }
}

enum TabsMode: String, CaseIterable, Identifiable {
    case allTabs
    case `import`

    var id: Self { self }

    var title: String {
        switch self {
            case .allTabs:
                "All Tabs"

            case .import:
                "Import"
        }
    }
}

enum CustomTab: String, Hashable, Identifiable, CaseIterable {
    case importFiles
    case browse
    case downloads
    case settings

    static let `default`: Self = .importFiles

    var id: Self { self }

    var title: String {
        switch self {
            case .importFiles:
                "Import"

            case .browse:
                "Discover"

            case .downloads:
                "Library"

            case .settings:
                "Settings"
        }
    }

    var iconAsset: String {
        switch self {
            case .browse:
                Constants.Icons.Browse.asset

            case .downloads:
                Constants.Icons.Downloads.asset

            case .importFiles:
                Constants.Icons.ImportFiles.asset

            case .settings:
                Constants.Icons.Settings.asset
        }
    }
}

struct RootTabsView: View {

    // MARK: - Main Body

    var body: some View {
        ZStack(alignment: .bottom) {
            content

            if playerVM.isPlayerVisible {
                CompactPlayerView(
                    track: playerVM.track,
                    isPlaying: playerVM.isPlaying,
                    progress: playerVM.progress,
                    repeatMode: playerVM.repeatMode,
                    isShuffleEnabled: playerVM.isShuffleEnabled,
                    sourceFormatText: playerVM.sourceFormatText,
                    outputRouteText: playerVM.outputRouteText,
                    onVinylPlateTap: {
                        openTrackSource()
                    },
                    onPlayPrevious: {
                        playerVM.playPrevious()
                    },
                    onPlayNext: {
                        playerVM.playNext()
                    },
                    onSeek: { delta in
                        playerVM.seek(by: delta)
                    },
                    onSeekHoldChanged: { isHolding, direction in
                        playerVM.setSeekScrubbing(isHolding, direction: direction)
                    },
                    onPlayPauseTap: {
                        playerVM.togglePlayPause()
                    },
                    onOpenExpandedPlayerTap: {
                        isExpandedPlayerPresented = true
                    },
                    onRepeatModeChange: { mode in
                        playerVM.setRepeatMode(mode)
                    },
                    onShuffleToggle: {
                        playerVM.toggleShuffle()
                    }
                )
                .padding(
                    .bottom,
                    rootTabsVM.isTabBarVisible
                    ? rootTabsVM.tabBarHeight
                    : GlobalConstants.CompactPlayer.bottomPadding
                )
                .offset(
                    y: screenHeight > GlobalConstants.Screen.seHeight
                    ? 0
                    : -18
                )
                .animation(.easeInOut(duration: 0.35), value: playerVM.isPlaying)
            }

            if rootTabsVM.isTabBarVisible {
                tabBar
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background {
            СustomSheet(
                isPresented: $isExpandedPlayerPresented) {
                ExpandedPlayerView(
                    screenHeight: screenHeight,
                    onClose: {
                        isExpandedPlayerPresented = false
                    }
                )
            }
        }
        .sheet(isPresented: $isPaywallPresented) {
            PaywallView()
                .presentationDetents([.fraction(0.58)])
        }
        .onChange(of: isPaywallPresented) { _, presented in
            settingsVM.isPaywallPresented = presented
        }
        .onChange(of: settingsVM.isPaywallPresented) { _, presented in
            isPaywallPresented = presented
        }
        .animation(
            .easeInOut(duration: 0.25),
            value: isExpandedPlayerPresented
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .bottom
        )
        .onAppear {
            restoreSelectedTab()
            playerVM.restoreLastPlaybackSession()
        }
        .task {
            playerVM.restoreLastPlaybackSession()
        }
        .onChange(of: rootTabsVM.tabsMode) { _, _ in
            restoreSelectedTab()
        }
        .onChange(of: coordinator.selectedTab) { _, newTab in
            rootTabsVM.rememberSelectedTab(newTab)
        }
    }

    // MARK: - Properties. Private

    @Environment(\.screenHeight) private var screenHeight
    @Injected private var rootTabsVM: RootTabsManaging
    @Injected private var playerVM: PlayerManaging
    @Injected private var importManagingVM: ImportManaging
    @Injected private var coverVM: CoverManaging
    @Injected private var settingsVM: SettingsManaging
    @Environment(\.themeManager) private var theme
    @Environment(AppCoordinator.self) private var coordinator
    @Namespace private var tabBarNamespace
    @State private var isPaywallPresented: Bool = false
    @State private var isExpandedPlayerPresented: Bool = false

    private var content: some View {
        Group {
            switch coordinator.selectedTab {
                case .browse:
                    BrowseView()

                case .downloads:
                    DownloadsView()

                case .importFiles:
                    NavigationStack(path: coordinator.pathBinding) {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationBarBackButtonHidden(true)
                            .navigationDestination(for: AppRoute.self) { route in
                                switch route {
                                    case .importHome:
                                        ImportsView()

                                    case .album(let album):
                                        AlbumDetailsView(album: album)

                                    case .albums:
                                        AlbumsView()

                                    case .artist(let artist, let segment):
                                        ArtistDetailsView(artist: artist, initialSegment: segment)

                                    case .artists:
                                        ArtistsView()

                                    case .covers(let album):
                                        AlbumCoversView(album: album)

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
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(rootTabsVM.visibleTabs) { tab in
                    TabItemView(
                        tab: tab,
                        isSelected: coordinator.selectedTab == tab,
                        activeColor: theme.tokens.tabIconActive,
                        inactiveColor: theme.tokens.tabIconInactive,
                        glassNamespace: tabBarNamespace,
                        onTap: {
                            coordinator.switchToTab(tab)
                        }
                    )
                }
            }
            .padding(.horizontal, 6)
            .frame(height: rootTabsVM.tabBarHeight)
            .glassEffect(in: .capsule)
        }
        .padding(.horizontal, 12)
        .offset(
            y: GlobalConstants.Device.isPad
            ? 5
            : screenHeight > GlobalConstants.Screen.seHeight
            ? 10
            : -10
        )
    }

    // MARK: - Private. Methods

    private func restoreSelectedTab() {
        coordinator.selectedTab = rootTabsVM.restoreSelectedTab()
    }

    private func openTrackSource() {
        if playerVM.playbackNavigationPath.isEmpty {
            playerVM.refreshPlaybackNavigationPath(library: importManagingVM.library)
        }

        let path = playerVM.playbackNavigationPath.map { route -> AppRoute in
            if case .artist(let artist, _) = route {
                return .artist(artist, segment: .tracks)
            }
            return route
        }
        guard path.isNotEmpty else { return }

        if isAtPlaybackSource(path) {
            playerVM.requestScrollToCurrentTrack()
            return
        }

        coordinator.switchToTab(.importFiles, animated: false)
        coordinator.popToRoot(animated: false)

        for route in path {
            coordinator.push(route, animated: false)
        }
    }

    private func isAtPlaybackSource(_ path: [AppRoute]) -> Bool {
        guard coordinator.selectedTab == .importFiles else { return false }

        let currentOrigin = PlaybackOriginSnapshot(from: coordinator.path)
        let targetOrigin = PlaybackOriginSnapshot(from: path)

        return currentOrigin != nil && currentOrigin == targetOrigin
    }

    // MARK: - Private. Object

    fileprivate struct TabItemView: View {

        // MARK: - Properties. Public

        fileprivate let tab: CustomTab
        fileprivate let isSelected: Bool
        fileprivate let activeColor: Color
        fileprivate let inactiveColor: Color
        fileprivate let glassNamespace: Namespace.ID
        fileprivate let onTap: () -> Void

        // MARK: - Main Body

        var body: some View {
            Button(
                action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                        onTap()
                    }
                },
                label: {
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(.clear)
                                .frame(width: selectionWidth, height: selectionHeight)
                                .glassEffect(
                                    .regular.tint(Color.white.opacity(0.35)).interactive(),
                                    in: .capsule
                                )
                                .glassEffectID("selectedTabPill", in: glassNamespace)
                        }

                        Image(tab.iconAsset)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(isSelected ? activeColor : inactiveColor)
                            .scaleEffect(isSelected ? 1.14 : 1.0)
                            .offset(y: isSelected ? -1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: iconHitHeight)
                    .contentShape(Rectangle())
                }
            )
            .buttonStyle(.plain)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
        }

        // MARK: - Properties. Private

        private let iconHitHeight: CGFloat = 44
        private let selectionWidth: CGFloat = 52
        private let selectionHeight: CGFloat = 40
    }
}

#Preview("Tab Bar Only") {
    @Previewable @Namespace var previewNamespace
    typealias TabItem = RootTabsView.TabItemView

    return ZStack(alignment: .bottom) {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(CustomTab.allCases) { tab in
                    TabItem(
                        tab: tab,
                        isSelected: tab == .default,
                        activeColor: Color(hex: 0x6B5CFF),
                        inactiveColor: Color.white.opacity(0.45),
                        glassNamespace: previewNamespace
                    ) {}
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 60)
            .glassEffect(in: .capsule)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
