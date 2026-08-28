//
//  CompactPlayerView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 10.07.2026.
//

import SwiftUI
import Resolver

struct CompactPlayerView: View {

    // MARK: - Properties. Public

    let track: TrackEntity?
    var isPlaying: Bool
    var progress: Double
    let repeatMode: RepeatMode
    let isShuffleEnabled: Bool
    let sourceFormatText: String
    let outputRouteText: String
    let onTrackInfoTap: () -> Void
    let onPlayPrevious: () -> Void
    let onPlayNext: () -> Void
    let onPlayPauseTap: () -> Void
    let onProgressTap: () -> Void
    let onRepeatModeChange: (RepeatMode) -> Void
    let onShuffleToggle: () -> Void

    // MARK: - Main Body

    var body: some View {
        if let track {
            VStack(spacing: 5) {
                MarqueeText(text: track.songName)
                    .equatable()
                    .padding(.leading, 20)

                ZStack(alignment: .bottom) {
                    HStack(spacing: 12) {
                        ZStack {
                            SpinningVinylView(
                                track: track,
                                isPlaying: isPlaying,
                                isLoading: coverVM.isLoading,
                                isSeekScrubbing: playerVM.isSeekScrubbing,
                                isTapSpinning: playerVM.isVinylTapSpinning,
                                progress: progress,
                                revolutionDuration: playerVM.vinylRevolutionDuration,
                                spinDirection: playerVM.vinylSpinDirection,
                                spinSpeed: playerVM.vinylSpinSpeed,
                                vinylSize: 44,
                                coverSize: 15,
                                holeSize: 1
                            )
                            .id(vinylAlbumKey(for: track))
                            .transition(.opacity.combined(with: .scale(scale: 0.88)))
                        }
                        .frame(size: 44)
                        .animation(.easeInOut(duration: 0.35), value: vinylAlbumKey(for: track))

                        Button(action: {
                            onTrackInfoTap()
                        }, label: {
                            Text(track.artistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 14)
                                .contentShape(Capsule())
                        })
                        .buttonStyle(PressGlassButtonStyle())

                        PlaybackControls(
                            isPlaying: isPlaying,
                            repeatMode: repeatMode,
                            isShuffleEnabled: isShuffleEnabled,
                            trackID: track.id,
                            onPlayPrevious: onPlayPrevious,
                            onPlayNext: onPlayNext,
                            onPlayPauseTap: onPlayPauseTap,
                            onRepeatModeChange: onRepeatModeChange,
                            onShuffleToggle: onShuffleToggle
                        )
                        .fixedSize()
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)

                    if progress > 0 {
                        ProgressBar(
                            progress: progress,
                            onProgressTap: onProgressTap
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                HStack {
                    sourceFormatLabel

                    Spacer()

                    outputRouteLabel
                }
                .frame(height: 10)
                .padding(.horizontal, 24)
            }
            .padding(.top, 5)
            .padding(.bottom, 10)
            .glassEffect(
                in: RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
            )
            .shadow(
                color: .black.opacity(0.18),
                radius: 12,
                y: 4
            )
            .task(id: "\(track.id)-\(coverVM.isConnected)") {
                guard coverVM.isConnected else { return }
                guard track.imagePath == nil else { return }
                guard track.artistName.isNotEmpty, track.albumName.isNotEmpty else { return }
                guard let data = await coverVM.fetchFrontCover(
                    artist: track.artistName,
                    album: track.albumName
                ) else { return }

                guard let album = importManagingVM.library?.albums.first(where: { album in
                    album.tracks.contains(where: { $0.id == track.id })
                }) else { return }

                await importManagingVM.applyCover(data, to: album)
            }
        }
    }

    // MARK: - Properties. Private

    @Injected private var importManagingVM: ImportManaging
    @Injected private var playerVM: PlayerManaging
    @Injected private var coverVM: CoverManaging

    private func vinylAlbumKey(for track: TrackEntity) -> String {
        "\(track.artistName)|\(track.albumName)"
    }

    private var sourceFormatLabel: some View {
        Text(sourceFormatText)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var outputRouteLabel: some View {
        Text(outputRouteText)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Private. Objects

    private struct PressGlassButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background {
                    Capsule()
                        .fill(.white.opacity(configuration.isPressed ? 0.22 : 0))
                }
                .glassEffect(
                    configuration.isPressed
                        ? .regular.interactive()
                        : .identity,
                    in: .capsule
                )
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }

    private struct PressCircleGlassButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background {
                    Circle()
                        .fill(.white.opacity(configuration.isPressed ? 0.22 : 0))
                }
                .glassEffect(
                    configuration.isPressed
                        ? .regular.interactive()
                        : .identity,
                    in: .circle
                )
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }

    private struct PlaybackControls: View {

        // MARK: - Properties. Public

        let isPlaying: Bool
        let repeatMode: RepeatMode
        let isShuffleEnabled: Bool
        let trackID: String?
        let onPlayPrevious: () -> Void
        let onPlayNext: () -> Void
        let onPlayPauseTap: () -> Void
        let onRepeatModeChange: (RepeatMode) -> Void
        let onShuffleToggle: () -> Void

        // MARK: - Body

        var body: some View {
            HStack(spacing: 0) {
                TrackSkipButton(
                    systemImage: "backward",
                    imageSize: imageSize,
                    action: onPlayPrevious
                )

                PlayPauseMenuButton(
                    isPlaying: isPlaying,
                    repeatMode: repeatMode,
                    isShuffleEnabled: isShuffleEnabled,
                    trackID: trackID,
                    imageSize: imageSize,
                    onPlayPauseTap: onPlayPauseTap,
                    onRepeatModeChange: onRepeatModeChange,
                    onShuffleToggle: onShuffleToggle
                )
                .equatable()

                TrackSkipButton(
                    systemImage: "forward",
                    imageSize: imageSize,
                    action: onPlayNext
                )
            }
            .font(.title3)
        }

        // MARK: - Private. Properties

        private let imageSize: CGFloat = 50
    }

    private struct TrackSkipButton: View {

        // MARK: - Properties. Public

        let systemImage: String
        let imageSize: CGFloat
        let action: () -> Void

        // MARK: - Body

        var body: some View {
            Button(action: action) {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
                    .frame(size: imageSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressCircleGlassButtonStyle())
        }
    }

    private struct PlayPauseMenuButton: View, Equatable {

        // MARK: - Properties. Public

        let isPlaying: Bool
        let repeatMode: RepeatMode
        let isShuffleEnabled: Bool
        let trackID: String?
        let imageSize: CGFloat
        let onPlayPauseTap: () -> Void
        let onRepeatModeChange: (RepeatMode) -> Void
        let onShuffleToggle: () -> Void

        // MARK: - Equatable

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.isPlaying == rhs.isPlaying
                && lhs.repeatMode == rhs.repeatMode
                && lhs.isShuffleEnabled == rhs.isShuffleEnabled
                && lhs.trackID == rhs.trackID
        }

        // MARK: - Body

        var body: some View {
            VStack(spacing: 0) {
                Button {
                    onPlayPauseTap()
                } label: {
                    Image(systemName: isPlaying ? "pause" : "play")
                        .foregroundStyle(.tint)
                        .frame(size: imageSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressCircleGlassButtonStyle())
                .contextMenu {
                    Button {
                        onRepeatModeChange(.one)
                    } label: {
                        Label {
                            Text("Repeat One")
                        } icon: {
                            if repeatMode == .one {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button {
                        onRepeatModeChange(.all)
                    } label: {
                        Label {
                            Text("Repeat All")
                        } icon: {
                            if repeatMode == .all {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button {
                        onRepeatModeChange(.off)
                    } label: {
                        Label {
                            Text("No Repeat")
                        } icon: {
                            if repeatMode == .off {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Divider()

                    Button {
                        onShuffleToggle()
                    } label: {
                        Label {
                            Text("Shuffle")
                        } icon: {
                            if isShuffleEnabled {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    Text(repeatMode == .one ? "•" : repeatMode == .all ? "••" : "")
                        .foregroundStyle(.blue)
                        .font(.system(size: 16))
                        .offset(y: 2)
                }
            }
        }
    }

    private struct ProgressBar: View {

        // MARK: - Properties. Public

        let progress: Double
        let onProgressTap: () -> Void

        // MARK: - Body

        var body: some View {
            ZStack {
                GeometryReader { geo in
                    Capsule()
                        .fill(.orange).opacity(0)
                        .frame(
                            width: geo.size.width * min(max(progress, 0), 1),
                            height: 3
                        )
                        .frame(
                            maxHeight: .infinity,
                            alignment: .bottom
                        )
                }

                Button {
                    onProgressTap()
                } label: {
                    Color.clear
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(height: 15)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
    }

    private struct MarqueeText: View, Equatable {

        // MARK: - Properties. Public

        let text: String

        // MARK: - Equatable

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.text == rhs.text
        }

        // MARK: - Body

        var body: some View {
            Text(text)
                .font(.headline)
                .lineLimit(1)
                .hidden()
                .overlay {
                    GeometryReader { geometry in
                        let containerWidth = geometry.size.width
                        let canScroll = textWidth > 0
                            && containerWidth > 0
                            && textWidth > containerWidth
                            && !text.isEmpty

                        Group {
                            if canScroll {
                                TimelineView(
                                    .animation(
                                        minimumInterval: 1.0 / 60.0,
                                        paused: false
                                    )
                                ) { context in
                                    HStack(spacing: textSpacing) {
                                        textView
                                        textView
                                    }
                                    .offset(x: offset(at: context.date))
                                }
                            } else {
                                textView
                            }
                        }
                        .frame(
                            width: containerWidth,
                            height: geometry.size.height,
                            alignment: .leading
                        )
                    }
                }
                .background(alignment: .leading) {
                    textView
                        .hidden()
                        .background {
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(
                                        key: MarqueeTextWidthKey.self,
                                        value: geometry.size.width
                                    )
                            }
                        }
                }
                .onPreferenceChange(MarqueeTextWidthKey.self) { newWidth in
                    guard textWidth != newWidth else { return }
                    textWidth = newWidth
                }
                .onChange(of: text) { _, _ in
                    cycleStartedAt = Date()
                }
                .frame(height: 22, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mask {
                    fadeMask
                }
        }

        // MARK: - Properties. Private

        @State private var textWidth: CGFloat = 0
        @State private var cycleStartedAt: Date = Date()

        private let speed: CGFloat = 35
        private let textSpacing: CGFloat = 100
        private let pauseDuration: TimeInterval = 2.5
        private let fadeWidth: CGFloat = 0

        private var textView: some View {
            Text(text)
                .font(.headline)
                .lineLimit(1)
                .fixedSize(
                    horizontal: true,
                    vertical: false
                )
        }

        private var fadeMask: some View {
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)

                Rectangle()
                    .fill(.black)

                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)
            }
        }

        // MARK: - Methods. Private

        private func offset(at date: Date) -> CGFloat {
            guard textWidth > 0 else {
                return 0
            }

            let distance = textWidth + textSpacing
            let scrollDuration = Double(distance / speed)
            let cycleDuration = pauseDuration + scrollDuration
            let elapsed = date.timeIntervalSince(cycleStartedAt)
            let cyclePosition = elapsed.truncatingRemainder(dividingBy: cycleDuration)

            if cyclePosition < pauseDuration {
                return 0
            }

            let scrollElapsed = cyclePosition - pauseDuration
            return -distance * min(scrollElapsed / scrollDuration, 1)
        }
    }

    private struct MarqueeTextWidthKey: PreferenceKey {

        // MARK: Properties. Public

        static var defaultValue: CGFloat = 0

        // MARK: - Methods. Public

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

}

// MARK: - Preview

#Preview {
    CompactPlayerView(
        track: TrackEntity(
            id: "1",
            image: "https://usercontent.jamendo.com/?type=album&id=24&width=300&trackid=168",
            songName: "Believer Very Very Very Very Very Very Very Very Long Title For Marquee Preview",
            duration: 200,
            artistName: "Imagine Dragons",
            albumName: "Evolve",
            releaseDate: "2017-02-01",
            download: nil,
            waveformData: nil,
            size: 5_242_880
        ),
        isPlaying: true,
        progress: 0.5,
        repeatMode: .one,
        isShuffleEnabled: false,
        sourceFormatText: "24 bit • 192 kHz • FLAC",
        outputRouteText: "Speaker • 48 kHz",
        onTrackInfoTap: {},
        onPlayPrevious: {},
        onPlayNext: {},
        onPlayPauseTap: {},
        onProgressTap: {},
        onRepeatModeChange: {_ in },
        onShuffleToggle: {}
    )
    .padding()
}
