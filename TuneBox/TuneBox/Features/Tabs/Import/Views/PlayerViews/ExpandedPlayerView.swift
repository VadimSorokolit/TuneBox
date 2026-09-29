//
//  ExpandedPlayerView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 10.07.2026.
//

import Resolver
import SwiftUI
import SDWebImageSwiftUI

struct ExpandedPlayerView: View {

    let screenHeight: CGFloat
    var onClose: () -> Void = {}

    // MARK: - Main Body

    var body: some View {
        ExpandedPlayerContent(
            isLargeScreen: isLargeScreen,
            screenHeight: screenHeight,
            playerVM: playerVM,
            coverVM: coverVM,
            onClose: onClose
        )
        .onAppear {
            print(isLargeScreen)
        }
    }

    #if DEBUG
    static func makePreview(
        screenHeight: CGFloat,
        track: TrackEntity,
        isPlaying: Bool = true,
        width: CGFloat
    ) -> some View {
        ExpandedPlayerContent(
            isLargeScreen: screenHeight > GlobalConstants.Screen.seHeight,
            screenHeight: screenHeight,
            playerVM: ExpandedPlayerPreviewPlayer(track: track, isPlaying: isPlaying),
            coverVM: ExpandedPlayerPreviewCover(),
            onClose: {}
        )
        .environment(\.screenHeight, screenHeight)
        .frame(width: width, height: screenHeight)
        .clipped()
        .overlay {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .background(Color.black)
    }
    #endif

    // MARK: - Properties. Private

    @Injected private var playerVM: PlayerManaging
    @Injected private var coverVM: CoverManaging

    private var isLargeScreen: Bool {
        let value = screenHeight > GlobalConstants.Screen.seHeight

        return value
    }

    // MARK: - Objects. Private

    private struct ExpandedPlayerContent: View {

        // MARK: - Properties. Public

        let isLargeScreen: Bool
        let screenHeight: CGFloat
        let playerVM: PlayerManaging
        let coverVM: CoverManaging
        let onClose: () -> Void

        // MARK: - Properties. Private

        @State private var sliderValue = 0.0
        @State private var metadataReveal: CGFloat = 0
        @State private var isSliding = false
        @State private var ignoreProgressSync = false

        private var displayedSliderValue: Double {
            if isSliding || ignoreProgressSync {
                return sliderValue
            }
            return playerVM.progress
        }

        // MARK: - Body

        var body: some View {
            if let track = playerVM.track {
                VStack(
                    spacing: isLargeScreen
                    ? 24
                    : 12
                ) {
                    header

                    SpinningVinylView(
                        track: track,
                        isPlaying: playerVM.isPlaying,
                        isLoading: coverVM.isLoading,
                        isSeekScrubbing: playerVM.isSeekScrubbing,
                        isTapSpinning: playerVM.isVinylTapSpinning,
                        progress: playerVM.progress,
                        revolutionDuration: playerVM.vinylRevolutionDuration,
                        spinDirection: playerVM.vinylSpinDirection,
                        spinSpeed: playerVM.vinylSpinSpeed,
                        vinylSize: isLargeScreen
                        ? 240
                        : 200,
                        coverSize: isLargeScreen
                        ? 96
                        : 80,
                        holeSize: 8
                    )
                    .equatable()
                    .transaction { $0.animation = nil }
                    .padding(.top, isLargeScreen ? 14 : 8)
                    .offset(y: vinylOffsetY)
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 12)

                    VStack(spacing: Constants.metadataSpacing) {
                        Text(track.songName)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(titleColor)
                            .shadow(color: .black.opacity(0.55), radius: 2, y: 1)

                        Text(track.artistName)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: Constants.artistMaxHeight,
                                alignment: .top
                            )
                            .foregroundStyle(subtitleColor)
                            .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: Constants.metadataBlockHeight,
                        maxHeight: Constants.metadataBlockHeight,
                        alignment: .top
                    )
                    .scaleEffect(metadataReveal, anchor: .center)
                    .opacity(metadataReveal * (playerVM.isPlaying ? 1 : 0.45))
                    .animation(.easeInOut(duration: 0.35), value: playerVM.isPlaying)
                    .padding(.top, 30)
                    .padding(.horizontal, 24)
                    .offset(y: metadataOffsetY)

                    visualizerSection(for: track)
                        .offset(y: controlsOffsetY)

                    playbackSection
                        .offset(y: controlsOffsetY)

                    formatSection
                        .offset(y: controlsOffsetY)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .background {
                    BlurredCoverBackground(coverPath: track.imagePath)
                        .animation(.easeInOut(duration: 0.4), value: track.id)
                }
                .onAppear {
                    sliderValue = playerVM.progress
                    revealMetadata(animated: true)
                }
                .onChange(of: track.id) { _, _ in
                    ignoreProgressSync = false
                    sliderValue = playerVM.progress
                    revealMetadata(animated: true)
                }
                .onChange(of: playerVM.progress) { _, progress in
                    guard isSliding.isFalse, ignoreProgressSync.isFalse else { return }
                    sliderValue = progress
                }
            } else {
                ContentUnavailableView(
                    L10n.Player.emptyTitle,
                    systemImage: "music.note",
                    description: Text(L10n.Player.emptyMessage)
                )
            }
        }

        // MARK: - Properties .Private

        private enum Constants {
            static let titleMaxHeight: CGFloat = 56
            static let artistMaxHeight: CGFloat = 40
            static let metadataSpacing: CGFloat = 6
            static let metadataBlockHeight =
                titleMaxHeight + artistMaxHeight + metadataSpacing

            /// Above SE and below Pro Max (~932) — e.g. 15 Pro (852), 11 (896).
            static let midHeightMin: CGFloat = 668
            static let midHeightMax: CGFloat = 920
            static let vinylOffsetSE: CGFloat = 30
            static let vinylOffsetMid: CGFloat = 30
            static let metadataOffsetCompact: CGFloat = 20
            static let controlsOffsetSE: CGFloat = -10
            static let controlsOffsetNonSE: CGFloat = -20
        }

        private var isMidHeightScreen: Bool {
            screenHeight >= Constants.midHeightMin
            && screenHeight < Constants.midHeightMax
        }

        private var usesCompactVerticalOffsets: Bool {
            isLargeScreen.isFalse || isMidHeightScreen
        }

        private var vinylOffsetY: CGFloat {
            usesCompactVerticalOffsets ? Constants.vinylOffsetMid : 0
        }

        private var metadataOffsetY: CGFloat {
            usesCompactVerticalOffsets ? Constants.metadataOffsetCompact : 0
        }

        private var controlsOffsetY: CGFloat {
            // SE keeps -10; everyone else lifts bottom another 10.
            if isLargeScreen.isFalse {
                return Constants.controlsOffsetSE
            }
            if usesCompactVerticalOffsets {
                return Constants.controlsOffsetNonSE
            }
            return Constants.controlsOffsetSE
        }

        private let titleColor = Color.white.mix(with: .primary, by: 0.12)
        private let subtitleColor = Color.white.mix(with: .secondary, by: 0.25)
        private let chromeColor = Color.white.mix(with: .primary, by: 0.18)
        private let accentColor = Color.orange.mix(with: .white, by: 0.35)

        private func revealMetadata(animated: Bool) {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                metadataReveal = 0
            }

            guard animated else {
                metadataReveal = 1
                return
            }

            Task { @MainActor in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                    metadataReveal = 1
                }
            }
        }

        private var header: some View {
            ZStack {
                HStack {
                    Spacer()

                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "chevron.compact.down")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(chromeColor)
                            .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
                            .frame(width: 44, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                HStack {
                    Spacer()

                    SleepTimerHeaderButton()
                }
            }
            .padding(
                .top,
                    isLargeScreen
                    ? 8
                    : 20
            )
        }

        private func visualizerSection(for track: TrackEntity) -> some View {
            let duration = TimeInterval(track.duration ?? 0)

            return VStack(spacing: 10) {
                PeakSquareHistogramView(
                    bands: playerVM.spectrumBands,
                    bandCount: playerVM.spectrumBandCount,
                    centers: playerVM.spectrumBandCenters,
                    isLargeScreen: isLargeScreen,
                    isActive: playerVM.track != nil
                )
                .id(track.id)
                .frame(height: 140)
                .padding(.bottom, 2)

                HStack {
                    Text(formatClock(playerVM.currentPlaybackTime))

                    Spacer()

                    if duration > 0 {
                        Text(formatClock(duration))
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(subtitleColor)
                .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
            }
            .offset(
                y: isLargeScreen
                ? 0
                : -30
            )
        }

        private var playbackSection: some View {
            VStack(spacing: 16) {
                Slider(
                    value: Binding(
                        get: { displayedSliderValue },
                        set: { newValue in
                            sliderValue = newValue
                            guard isSliding else { return }
                            playerVM.seek(to: newValue)
                        }
                    ),
                    in: 0 ... 1
                ) { editing in
                    if editing {
                        sliderValue = playerVM.progress
                        isSliding = true
                        ignoreProgressSync = false
                    } else {
                        // Playing + at end: don't let progress 1→0 redraw this slider instance.
                        if sliderValue >= 1, playerVM.isPlaying {
                            ignoreProgressSync = true

                            Task { @MainActor in
                                // repeat .one keeps the same track id — unfreeze shortly after.
                                try? await Task.sleep(nanoseconds: 120_000_000)
                                guard ignoreProgressSync else { return }
                                ignoreProgressSync = false
                                guard isSliding.isFalse else { return }
                                sliderValue = playerVM.progress
                            }
                        }
                        isSliding = false
                    }
                    playerVM.setSeekScrubbing(editing, direction: 0)
                }
                .tint(accentColor)
                .id(playerVM.track?.id)

                HStack(spacing: 36) {
                    TrackSkipHoldButton(
                        systemImage: "backward.fill",
                        imageSize: 44,
                        direction: -1,
                        isSeekDisabled: playerVM.progress <= 0,
                        onSkip: {
                            playerVM.playPrevious()
                        },
                        onSeek: { delta in
                            playerVM.seek(by: delta)
                        },
                        onSeekHoldChanged: { isHolding, direction in
                            playerVM.setSeekScrubbing(isHolding, direction: direction)
                        }
                    )

                    Button {
                        playerVM.togglePlayPause()
                    } label: {
                        Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                    }

                    TrackSkipHoldButton(
                        systemImage: "forward.fill",
                        imageSize: 44,
                        direction: 1,
                        isSeekDisabled: playerVM.progress >= 1,
                        onSkip: {
                            playerVM.playNext()
                        },
                        onSeek: { delta in
                            playerVM.seek(by: delta)
                        },
                        onSeekHoldChanged: { isHolding, direction in
                            playerVM.setSeekScrubbing(isHolding, direction: direction)
                        }
                    )
                }
                .foregroundStyle(chromeColor)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .buttonStyle(.plain)
            }
            .offset(
                y: isLargeScreen
                ? 0
                : -30
            )
        }

        private var formatSection: some View {
            HStack {
                Text(playerVM.sourceFormatText)

                Spacer()

                Text(playerVM.outputRouteText)
                    .multilineTextAlignment(.trailing)
            }
            .font(.caption2)
            .foregroundStyle(subtitleColor)
            .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
            .frame(height: 15)
            .scaleEffect(
                x: 1,
                y: playerVM.isPlaying ? 1 : 0,
                anchor: .center
            )
            .opacity(playerVM.isPlaying ? 1 : 0)
            .playbackAnimation(playerVM.isPlaying)
            .offset(
                y: isLargeScreen
                ? 0
                : -30
            )
        }

        private func formatClock(_ seconds: TimeInterval) -> String {
            let total = max(0, Int(seconds.rounded()))
            let minutes = total / 60
            let remaining = total % 60

            return String(format: "%d:%02d", minutes, remaining)
        }

        private struct TrackSkipHoldButton: View {

            // MARK: - Properties. Public

            let systemImage: String
            let imageSize: CGFloat
            let direction: Double
            let isSeekDisabled: Bool
            let onSkip: () -> Void
            let onSeek: (TimeInterval) -> Void
            let onSeekHoldChanged: (Bool, Double) -> Void

            // MARK: - Body

            var body: some View {
                Color.clear
                    .frame(width: imageSize, height: imageSize)
                    .contentShape(Rectangle())
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.title2)
                            .opacity(isPressed ? 0.55 : 1)
                            .scaleEffect(isPressed ? 0.92 : 1)
                    }
                    .animation(.easeOut(duration: 0.15), value: isPressed)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                beginPress()
                            }
                            .onEnded { _ in
                                endPress()
                            }
                    )
                    .onChange(of: isSeekDisabled) { _, disabled in
                        guard disabled, isPressed else { return }
                        holdTask?.cancel()
                        holdTask = nil
                        didEnterHold = true
                    }
                    .onDisappear {
                        endPress()
                    }
            }

            // MARK: - Private. Properties

            @State private var holdTask: Task<Void, Never>?
            @State private var didEnterHold = false
            @State private var isPressed = false

            private let holdStepSeconds: TimeInterval = 1
            private let holdDelayNanoseconds: UInt64 = 300_000_000
            private let holdTickNanoseconds: UInt64 = 120_000_000

            // MARK: - Private. Methods

            private func beginPress() {
                guard isPressed.isFalse else { return }
                guard holdTask == nil else { return }

                isPressed = true
                didEnterHold = false
                if isSeekDisabled.isFalse {
                    onSeekHoldChanged(true, direction)
                }
                holdTask = Task { @MainActor in
                    do {
                        try await Task.sleep(nanoseconds: holdDelayNanoseconds)
                    } catch {
                        return
                    }

                    guard !Task.isCancelled else { return }
                    didEnterHold = true
                    guard isSeekDisabled.isFalse else { return }

                    while !Task.isCancelled {
                        guard isSeekDisabled.isFalse else { return }

                        onSeek(direction * holdStepSeconds)
                        do {
                            try await Task.sleep(nanoseconds: holdTickNanoseconds)
                        } catch {
                            return
                        }
                    }
                }
            }

            private func endPress() {
                let wasHolding = didEnterHold
                let wasPressed = isPressed
                cancelHold()
                isPressed = false

                guard wasPressed else { return }

                onSeekHoldChanged(false, direction)

                guard wasHolding.isFalse else { return }
                onSkip()
            }

            private func cancelHold() {
                holdTask?.cancel()
                holdTask = nil
                didEnterHold = false
            }
        }
    }

    private struct BlurredCoverBackground: View {

        // MARK: - Properties. Public

        let coverPath: String?

        // MARK: - Body

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemBackground)

                    WebImage(url: CoverImageLoader.imageURL(for: coverPath)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .clipped()
                    .blur(radius: 48)

                    LinearGradient.blackScrim

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.35)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

#if DEBUG

private enum ExpandedPlayerPreviewData {
    static let shortTrack = TrackEntity(
        id: "preview-short",
        image: "https://usercontent.jamendo.com/?type=album&id=24&width=300&trackid=168",
        songName: "Get Lucky",
        duration: 369,
        artistName: "Daft Punk",
        albumName: "Random Access Memories",
        releaseDate: "2013",
        download: nil,
        waveformData: nil,
        size: 5_242_880
    )

    static let longTrack = TrackEntity(
        id: "preview-long",
        image: "https://usercontent.jamendo.com/?type=album&id=24&width=300&trackid=168",
        songName: "Believer Very Very Very Long Title That Always Wraps To Two Lines",
        duration: 204,
        artistName: "Imagine Dragons And Friends With A Very Long Artist Name",
        albumName: "Evolve",
        releaseDate: "2017",
        download: nil,
        waveformData: nil,
        size: 5_242_880
    )
}

@MainActor
@Observable
private final class ExpandedPlayerPreviewPlayer: PlayerManaging {
    private(set) var track: TrackEntity?
    private(set) var playlist: PlaylistEntity?
    private(set) var playbackNavigationPath: [AppRoute] = []
    private(set) var scrollToCurrentTrackRequest = 0
    private(set) var repeatMode: RepeatMode = .off
    private(set) var spectrumBands: [Float]
    private(set) var spectrumBandCount = 32
    private(set) var spectrumBandCenters: [Float]
    private(set) var progress: Double = 0.42
    private(set) var sourceFormatText = "24 bit • 96 kHz • FLAC"
    private(set) var outputRouteText = "Speaker • 48 kHz"
    let vinylRevolutionDuration: TimeInterval = 18
    private(set) var vinylSpinDirection: Double = 1
    private(set) var vinylSpinSpeed: Double = 1
    private(set) var isSeekScrubbing = false
    private(set) var isVinylTapSpinning = false
    private(set) var isPlaying: Bool
    private(set) var isShuffleEnabled = false
    var isPlayerVisible: Bool { true }
    var currentPlaybackTime: TimeInterval { progress * TimeInterval(track?.duration ?? 0) }

    init(track: TrackEntity, isPlaying: Bool) {
        self.track = track
        self.isPlaying = isPlaying
        self.spectrumBands = (0..<32).map { index in
            Float(0.25 + 0.55 * abs(sin(Double(index) * 0.45)))
        }
        self.spectrumBandCenters = (0..<32).map { Float($0) }
    }

    func handlePlayAction(for track: TrackEntity, in queue: [TrackEntity], navigationPath: [AppRoute]?) {}
    func togglePlayPause() { isPlaying.toggle() }
    func restoreLastPlaybackSession() {}
    func persistPlaybackSession() {}
    func refreshPlaybackNavigationPath(library: MusicLibrary?) {}
    func requestScrollToCurrentTrack() {}
    func resetPlayback() {}
    func stopAudioPreservingSession() {}
    func clearPlaybackIfAffected(byRemovedSourceID sourceID: UUID, isAPISource: Bool) {}
    func appendDownloadedTracks(_ tracks: [TrackEntity]) {}
    func isPlaying(_ track: TrackEntity) -> Bool { isPlaying && self.track?.id == track.id }
    func seek(by deltaSeconds: TimeInterval) {}
    func seek(to progress: Double) { self.progress = progress }
    func setSeekScrubbing(_ isScrubbing: Bool, direction: Double) { isSeekScrubbing = isScrubbing }
    func playNext() {}
    func playPrevious() {}
    func loadPlaylist() {}
    func setRepeatMode(_ mode: RepeatMode) { repeatMode = mode }
    func toggleShuffle() { isShuffleEnabled.toggle() }
}

@MainActor
@Observable
private final class ExpandedPlayerPreviewCover: CoverManaging {
    var isLoading = false
    var error: String?
    var isConnected = true

    func fetchFrontCover(artist: String, album: String) async -> Data? { nil }
}

#Preview("15 Pro Max") {
    ExpandedPlayerView.makePreview(
        screenHeight: 932,
        track: ExpandedPlayerPreviewData.longTrack,
        width: 430
    )
}

#Preview("11") {
    ExpandedPlayerView.makePreview(
        screenHeight: 896,
        track: ExpandedPlayerPreviewData.longTrack,
        width: 414
    )
}

#Preview("15 Pro") {
    ExpandedPlayerView.makePreview(
        screenHeight: 852,
        track: ExpandedPlayerPreviewData.longTrack,
        width: 393
    )
}

#Preview("SE") {
    ExpandedPlayerView.makePreview(
        screenHeight: 667,
        track: ExpandedPlayerPreviewData.longTrack,
        width: 375
    )
}

#endif
