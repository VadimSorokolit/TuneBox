//
//  CompactPlayerView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 10.07.2026.
//

import SwiftUI

struct CompactPlayerView: View {

    // MARK: - Properties. Public

    let track: TrackEntity?
    var isPlaying: Bool
    var progress: Double
    let onRewindTap: () -> Void
    let onPlayPauseTap: () -> Void
    let onForwardTap: () -> Void
    let onProgressTap: () -> Void

    // MARK: - Main Body

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 12) {
                ArtworkView(
                    artworkPath: track?.imagePath,
                    size: 44,
                    cornerRadius: 8
                )

                VStack(
                    alignment: .leading,
                    spacing: track?.artistName.isEmpty == true ? 0 : 2
                ) {
                    MarqueeText(text: track?.songName ?? "")

                    Text(track?.artistName ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(-1)

                PlaybackControls(
                    isPlaying: isPlaying,
                    progress: progress,
                    onRewindTap: onRewindTap,
                    onPlayPauseTap: onPlayPauseTap,
                    onForwardTap: onForwardTap
                )
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .frame(maxWidth: .infinity)

            ProgressBar(
                progress: progress,
                onProgressTap: onProgressTap
            )
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
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
    }
}

// MARK: - Private. Objects

private struct PlaybackControls: View {

    // MARK: - Properties. Public

    let isPlaying: Bool
    let progress: Double
    let onRewindTap: () -> Void
    let onPlayPauseTap: () -> Void
    let onForwardTap: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            Button {
                onRewindTap()
            } label: {
                Image(systemName: "gobackward.10")
                    .frame(size: imageSize)
            }
            .disabled(progress == 0)

            Button {
                onPlayPauseTap()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .frame(size: imageSize)
            }

            Button {
                onForwardTap()
            } label: {
                Image(systemName: "goforward.10")
                    .frame(size: imageSize)
            }
            .disabled(progress == 1)
        }
        .font(.title3)
    }

    // MARK: - Private. Properties

    private let imageSize: CGFloat = 40
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
                    .fill(.orange)
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

private struct MarqueeText: View {

    // MARK: - Properties. Public

    let text: String

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
                        && !text.isEmpty

                    Group {
                        if canScroll {
                            TimelineView(
                                .animation(
                                    minimumInterval: 1.0 / 30.0,
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

    private let speed: CGFloat = 100
    private let textSpacing: CGFloat = 100
    private let pauseDuration: TimeInterval = 1.5
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
        onRewindTap: {},
        onPlayPauseTap: {},
        onForwardTap: {},
        onProgressTap: {}
    )
    .padding()
}
