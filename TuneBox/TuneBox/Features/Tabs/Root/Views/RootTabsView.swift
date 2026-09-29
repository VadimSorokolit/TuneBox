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
        static var defaultNavigationTitle: String { L10n.Library.tracks }
    }

    enum Icons {
        enum Browse {
            static let asset = "TabDiscover"
        }

        enum Downloads {
            static let asset = "TabLibrary"
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
                L10n.TabsMode.all

            case .import:
                L10n.TabsMode.import
        }
    }
}

enum CustomTab: String, Hashable, Identifiable, CaseIterable, Sendable {
    case importFiles
    case browse
    case downloads
    case settings

    nonisolated static let `default`: Self = .importFiles

    var id: Self { self }

    var title: String {
        switch self {
            case .importFiles:
                L10n.Tab.import

            case .browse:
                L10n.Tab.discover

            case .downloads:
                L10n.Tab.library

            case .settings:
                L10n.Tab.settings
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
        // swiftlint:disable:next redundant_discardable_let
        let _ = languageRefreshID

        ZStack(alignment: .bottom) {
            content
                // Keep tab screens still — only the glass pill should leap
                .animation(nil, value: coordinator.selectedTab)

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
        .overlay(alignment: .topTrailing) {
            SleepTimerHeaderButton()
                .padding(.trailing, GlobalConstants.Screen.horizontalInset)
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
        .sheet(isPresented: paywallPresented) {
            PaywallView()
                .presentationDetents([paywallPresentationDetent])
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
    @Environment(\.languageRefreshID) private var languageRefreshID
    @Injected private var rootTabsVM: RootTabsManaging
    @Injected private var playerVM: PlayerManaging
    @Injected private var importManagingVM: ImportManaging
    @Injected private var coverVM: CoverManaging
    @Injected private var settingsVM: SettingsManaging
    @Environment(\.themeManager) private var theme
    @Environment(AppCoordinator.self) private var coordinator
    @State private var isExpandedPlayerPresented: Bool = false

    private var paywallPresented: Binding<Bool> {
        Binding(
            get: { settingsVM.isPaywallPresented },
            set: { settingsVM.isPaywallPresented = $0 }
        )
    }

    private var paywallPresentationDetent: PresentationDetent {
        .fraction(screenHeight > GlobalConstants.Screen.seHeight ? 0.58 : 0.78)
    }

    private var content: some View {
        ZStack {
            keptAliveTab(.browse) {
                BrowseView()
            }

            keptAliveTab(.downloads) {
                DownloadsView()
            }

            keptAliveTab(.importFiles) {
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
            }

            keptAliveTab(.settings) {
                SettingsView()
            }
        }
    }

    @ViewBuilder
    private func keptAliveTab<Content: View>(
        _ tab: CustomTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isSelected = coordinator.selectedTab == tab

        content()
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
            .zIndex(isSelected ? 1 : 0)
    }

    private var tabBar: some View {
        let tabs = rootTabsVM.visibleTabs
        let selectedIndex = tabs.firstIndex(of: coordinator.selectedTab) ?? 0
        let pillWidth: CGFloat = 64
        let pillHeight: CGFloat = 44
        let iconSize: CGFloat = 24
        let horizontalInset: CGFloat = 8

        return ZStack {
            // Static track.
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: .capsule)

            // Selection glass — same layout width as the icon row.
            GeometryReader { geo in
                let count = max(tabs.count, 1)
                let contentWidth = geo.size.width - horizontalInset * 2
                let slotWidth = contentWidth / CGFloat(count)
                let centerX = horizontalInset
                    + slotWidth * (CGFloat(selectedIndex) + 0.5)

                Capsule()
                    .fill(.clear)
                    .frame(width: pillWidth, height: pillHeight)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .position(x: centerX, y: geo.size.height / 2)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.86),
                        value: selectedIndex
                    )
                    .allowsHitTesting(false)
            }

            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    Button {
                        coordinator.switchToTab(tab)
                    } label: {
                        Image(tab.iconAsset)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundStyle(
                                index == selectedIndex
                                ? theme.tokens.tabIconActive
                                : theme.tokens.tabIconInactive
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, horizontalInset)
            .animation(nil, value: selectedIndex)
        }
        .frame(height: rootTabsVM.tabBarHeight)
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
}

#Preview("Tab Bar Only") {
    @Previewable @State var selected = CustomTab.default

    return ZStack(alignment: .bottom) {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        let tabs = CustomTab.allCases
        let selectedIndex = tabs.firstIndex(of: selected) ?? 0
        let pillWidth: CGFloat = 64
        let pillHeight: CGFloat = 44
        let horizontalInset: CGFloat = 8

        ZStack {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: .capsule)

            GeometryReader { geo in
                let count = max(tabs.count, 1)
                let contentWidth = geo.size.width - horizontalInset * 2
                let slotWidth = contentWidth / CGFloat(count)
                let centerX = horizontalInset
                    + slotWidth * (CGFloat(selectedIndex) + 0.5)

                Capsule()
                    .fill(.clear)
                    .frame(width: pillWidth, height: pillHeight)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .position(x: centerX, y: geo.size.height / 2)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.86),
                        value: selectedIndex
                    )
                    .allowsHitTesting(false)
            }

            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    Button {
                        selected = tab
                    } label: {
                        Image(tab.iconAsset)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(
                                index == selectedIndex
                                ? Color(hex: 0x007AFF)
                                : Color.white.opacity(0.45)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, horizontalInset)
        }
        .frame(height: 60)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
