//
//  ExpandedPlayerView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 10.07.2026.
//

import Resolver
import SwiftUI

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
                        .padding(.top, 8)

                        VStack(spacing: 6) {
                            Text(track.songName)
                                .font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)

                            Text(track.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 24)

                        visualizerSection(for: track)

                        playbackSection

                        formatSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .background(Color(.systemBackground))
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

        private var header: some View {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.compact.down")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
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
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 4,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: 16
                    )
                )

                HStack {
                    Text(formatClock(playerVM.currentPlaybackTime))

                    Spacer()

                    if duration > 0 {
                        Text(formatClock(duration))
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
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
                .tint(.orange)

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
                .foregroundStyle(.primary)
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
            .foregroundStyle(.secondary)
        }

        private func formatClock(_ seconds: TimeInterval) -> String {
            let total = max(0, Int(seconds.rounded()))
            let minutes = total / 60
            let remaining = total % 60

            return String(format: "%d:%02d", minutes, remaining)
        }
    }

}

#Preview {
    ExpandedPlayerView()
}
