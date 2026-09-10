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

    // MARK: - Main Body

    var body: some View {
        ExpandedPlayerContent(
            playerVM: playerVM,
            coverVM: coverVM,
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

        @Environment(\.dismiss) private var dismiss

        private static let titleColor = Color.white.mix(with: .primary, by: 0.12)
        private static let subtitleColor = Color.white.mix(with: .secondary, by: 0.25)
        private static let chromeColor = Color.white.mix(with: .primary, by: 0.18)
        private static let accentColor = Color.orange.mix(with: .white, by: 0.35)

        private var header: some View {
            HStack {
                Spacer()

                Button {
                    dismiss()
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
                    Button {
                        playerVM.playPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }

                    Button {
                        playerVM.togglePlayPause()
                    } label: {
                        Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                    }

                    Button {
                        playerVM.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
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
        }

        private func formatClock(_ seconds: TimeInterval) -> String {
            let total = max(0, Int(seconds.rounded()))
            let minutes = total / 60
            let remaining = total % 60

            return String(format: "%d:%02d", minutes, remaining)
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

                    WebImage(url: coverURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .blur(radius: 48)
                    .scaleEffect(1.12)

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.2),
                            Color.black.opacity(0.45),
                            Color.black.opacity(0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.35)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }

        // MARK: - Properties. Private

        private var coverURL: URL? {
            guard let coverPath, coverPath.isEmpty == false else {
                return nil
            }

            if coverPath.hasPrefix("http://") || coverPath.hasPrefix("https://") {
                return URL(string: coverPath)
            }

            return AudioMetadataService.coverURL(for: coverPath)
        }
    }

}

#Preview {
    ExpandedPlayerView()
}
