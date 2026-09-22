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

    var onClose: () -> Void = {}

    // MARK: - Main Body

    var body: some View {
        ExpandedPlayerContent(
            playerVM: playerVM,
            coverVM: coverVM,
            onClose: onClose
        )
    }

    // MARK: - Properties. Private

    @Injected private var playerVM: PlayerManaging
    @Injected private var coverVM: CoverManaging

    // MARK: - Objects. Private

    private struct ExpandedPlayerContent: View {

        // MARK: - Properties. Public

        let playerVM: PlayerManaging
        let coverVM: CoverManaging
        let onClose: () -> Void

        // MARK: - Body

        var body: some View {
            if let track = playerVM.track {
                ScrollView {
                    VStack(spacing: 24) {
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
                            vinylSize: 240,
                            coverSize: 96,
                            holeSize: 8
                        )
                        .equatable()
                        .transaction { $0.animation = nil }
                        .padding(.top, 8)
                        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)

                        VStack(spacing: 6) {
                            Text(track.songName)
                                .font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .foregroundStyle(Self.titleColor)
                                .shadow(color: .black.opacity(0.55), radius: 2, y: 1)

                            Text(track.artistName)
                                .font(.subheadline)
                                .foregroundStyle(Self.subtitleColor)
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
                        }
                        .padding(.horizontal, 24)

                        visualizerSection(for: track)

                        playbackSection

                        formatSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .background {
                    BlurredCoverBackground(coverPath: track.imagePath)
                        .animation(.easeInOut(duration: 0.4), value: track.id)
                }
            } else {
                ContentUnavailableView(
                    "No Track",
                    systemImage: "music.note",
                    description: Text("Start playback to use the expanded player.")
                )
            }
        }

        // MARK: - Properties .Private

        private static let titleColor = Color.white.mix(with: .primary, by: 0.12)
        private static let subtitleColor = Color.white.mix(with: .secondary, by: 0.25)
        private static let chromeColor = Color.white.mix(with: .primary, by: 0.18)
        private static let accentColor = Color.orange.mix(with: .white, by: 0.35)

        private var header: some View {
            HStack {
                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "chevron.compact.down")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Self.chromeColor)
                        .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
                        .frame(width: 44, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 8)
        }

        private func visualizerSection(for track: TrackEntity) -> some View {
            let duration = TimeInterval(track.duration ?? 0)

            return VStack(spacing: 10) {
                PeakSquareHistogramView(
                    bands: playerVM.spectrumBands,
                    bandCount: playerVM.spectrumBandCount,
                    centers: playerVM.spectrumBandCenters,
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
                .foregroundStyle(Self.subtitleColor)
                .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
            }
        }

        private var playbackSection: some View {
            VStack(spacing: 16) {
                Slider(
                    value: Binding(
                        get: { playerVM.progress },
                        set: { playerVM.seek(to: $0) }
                    ),
                    in: 0 ... 1
                ) { editing in
                    playerVM.setSeekScrubbing(editing, direction: 0)
                }
                .tint(Self.accentColor)

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
                .foregroundStyle(Self.chromeColor)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .buttonStyle(.plain)
            }
        }

        private var formatSection: some View {
            HStack {
                Text(playerVM.sourceFormatText)

                Spacer()

                Text(playerVM.outputRouteText)
                    .multilineTextAlignment(.trailing)
            }
            .font(.caption2)
            .foregroundStyle(Self.subtitleColor)
            .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
            .frame(height: 15)
            .scaleEffect(
                x: 1,
                y: playerVM.isPlaying ? 1 : 0,
                anchor: .center
            )
            .opacity(playerVM.isPlaying ? 1 : 0)
            .playbackAnimation(playerVM.isPlaying)
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

#Preview {
    ExpandedPlayerView()
}
