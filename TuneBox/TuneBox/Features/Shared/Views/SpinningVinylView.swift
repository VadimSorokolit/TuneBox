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
    let isSeekScrubbing: Bool
    let isTapSpinning: Bool
    let progress: Double
    let revolutionDuration: TimeInterval
    let spinDirection: Double
    let spinSpeed: Double
    let vinylSize: CGFloat
    let coverSize: CGFloat
    let holeSize: CGFloat
    var onTap: (() -> Void)?

    // MARK: - Initializer

    init(
        track: TrackEntity,
        isPlaying: Bool,
        isLoading: Bool,
        isSeekScrubbing: Bool,
        isTapSpinning: Bool,
        progress: Double,
        revolutionDuration: TimeInterval,
        spinDirection: Double,
        spinSpeed: Double,
        vinylSize: CGFloat,
        coverSize: CGFloat,
        holeSize: CGFloat,
        onTap: (() -> Void)? = nil
    ) {
        self.track = track
        self.isPlaying = isPlaying
        self.isLoading = isLoading
        self.isSeekScrubbing = isSeekScrubbing
        self.isTapSpinning = isTapSpinning
        self.progress = progress
        self.revolutionDuration = revolutionDuration
        self.spinDirection = spinDirection
        self.spinSpeed = spinSpeed
        self.vinylSize = vinylSize
        self.coverSize = coverSize
        self.holeSize = holeSize
        self.onTap = onTap
    }

    // MARK: - Main Body

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: shouldSpin.isFalse
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
                .animation(progressAnimation, value: progress)
            }
            .contentShape(Circle())
            .onTapGesture {
                onTap?()
            }
        }
        .onAppear {
            syncSpinState()
        }
        .onChange(of: shouldSpin) { _, _ in
            syncSpinState()
        }
        .onChange(of: spinDirection) { _, _ in
            restartSpinPreservingAngle()
        }
        .onChange(of: spinSpeed) { _, _ in
            restartSpinPreservingAngle()
        }
    }

    // MARK: - Properties. Private

    @State private var spinStartedAt: Date?
    @State private var baseRotation: Double = 0
    @State private var activeDirection: Double = 1
    @State private var activeSpeed: Double = 1

    private var shouldSpin: Bool {
        isPlaying || isSeekScrubbing || isTapSpinning
    }

    private var visibleSize: CGFloat {
        vinylSize - (vinylSize - coverSize) * progress
    }

    private var progressAnimation: Animation? {
        if isSeekScrubbing || isTapSpinning {
            return .easeInOut(duration: 0.35)
        }

        return nil
    }

    // MARK: - Methods. Private

    private func spinDegrees(at date: Date) -> Double {
        guard let spinStartedAt else {
            return 0
        }

        let elapsed = date.timeIntervalSince(spinStartedAt)

        return elapsed / revolutionDuration * 360 * activeDirection * activeSpeed
    }

    private func syncSpinState() {
        if shouldSpin {
            guard spinStartedAt == nil else {
                return
            }

            activeDirection = spinDirection
            activeSpeed = spinSpeed
            spinStartedAt = Date()
        } else {
            freezeCurrentAngle()
            spinStartedAt = nil
        }
    }

    private func restartSpinPreservingAngle() {
        guard shouldSpin else {
            return
        }

        freezeCurrentAngle()
        activeDirection = spinDirection
        activeSpeed = spinSpeed
        spinStartedAt = Date()
    }

    private func freezeCurrentAngle() {
        guard let spinStartedAt else {
            return
        }

        let elapsed = Date().timeIntervalSince(spinStartedAt)
        baseRotation += elapsed / revolutionDuration * 360 * activeDirection * activeSpeed
    }
}
