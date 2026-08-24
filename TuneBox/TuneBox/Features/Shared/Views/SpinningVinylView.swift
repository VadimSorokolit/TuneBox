//
//  SpinningVinylView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 24.08.2026.
//

import SwiftUI

struct SpinningVinylView: View {

    // MARK: - Properties. Public

    let track: TrackEntity
    let isPlaying: Bool
    let isLoading: Bool
    let progress: Double
    let revolutionDuration: TimeInterval
    let vinylSize: CGFloat
    let coverSize: CGFloat
    let holeSize: CGFloat
    var onTap: (() -> Void)? = nil

    // MARK: - Main Body

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: isPlaying.isFalse
            )
        ) { context in
            let spinDegrees = self.spinDegrees(at: context.date)

            ZStack {
                VinylPlateView(
                    track: track,
                    isLoading: isLoading,
                    vinylImageSize: vinylSize,
                    coverImageSize: coverSize,
                    centerHoleSize: holeSize,
                    rotation: 0
                )
                .allowsHitTesting(false)
                .opacity(0.15)

                VinylPlateView(
                    track: track,
                    isLoading: isLoading,
                    vinylImageSize: vinylSize,
                    coverImageSize: coverSize,
                    centerHoleSize: holeSize,
                    rotation: baseRotation + spinDegrees
                )
                .allowsHitTesting(false)
                .mask {
                    Circle()
                        .frame(size: visibleSize)
                }
            }
            .contentShape(Circle())
            .onTapGesture {
                onTap?()
            }
        }
        .onAppear {
            updateVinylSpin(isPlaying: isPlaying)
        }
        .onChange(of: isPlaying) { _, playing in
            updateVinylSpin(isPlaying: playing)
        }
    }

    // MARK: - Properties. Private

    @State private var spinStartedAt: Date?
    @State private var baseRotation: Double = 0

    private var visibleSize: CGFloat {
        vinylSize - (vinylSize - coverSize) * progress
    }

    // MARK: - Methods. Private

    private func spinDegrees(at date: Date) -> Double {
        guard let spinStartedAt else {
            return 0
        }

        let elapsed = date.timeIntervalSince(spinStartedAt)

        return elapsed / revolutionDuration * 360
    }

    private func updateVinylSpin(isPlaying: Bool) {
        if isPlaying {
            guard spinStartedAt == nil else {
                return
            }

            spinStartedAt = Date()
        } else if let spinStartedAt {
            let elapsed = Date().timeIntervalSince(spinStartedAt)
            baseRotation += elapsed / revolutionDuration * 360
            self.spinStartedAt = nil
        }
    }
}
