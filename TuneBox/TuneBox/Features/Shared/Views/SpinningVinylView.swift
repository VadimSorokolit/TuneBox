//
//  SpinningVinylView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 24.08.2026.
//

import SwiftUI
import UIKit

struct SpinningVinylView: View, Equatable {

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

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.track.id == rhs.track.id
            && lhs.track.imagePath == rhs.track.imagePath
            && lhs.isPlaying == rhs.isPlaying
            && lhs.isLoading == rhs.isLoading
            && lhs.isSeekScrubbing == rhs.isSeekScrubbing
            && lhs.isTapSpinning == rhs.isTapSpinning
            && lhs.progress == rhs.progress
            && lhs.revolutionDuration == rhs.revolutionDuration
            && lhs.spinDirection == rhs.spinDirection
            && lhs.spinSpeed == rhs.spinSpeed
            && lhs.vinylSize == rhs.vinylSize
            && lhs.coverSize == rhs.coverSize
            && lhs.holeSize == rhs.holeSize
    }

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
        ZStack {
            VinylIdlePlate(
                track: track,
                isLoading: isLoading,
                vinylSize: vinylSize,
                coverSize: coverSize,
                holeSize: holeSize
            )
            .equatable()
            .allowsHitTesting(false)
            .opacity(0.15)

            VinylSpinningDisc(
                track: track,
                isLoading: isLoading,
                isSpinning: shouldSpin,
                spinDirection: spinDirection,
                spinSpeed: spinSpeed,
                revolutionDuration: revolutionDuration,
                vinylSize: vinylSize,
                coverSize: coverSize,
                holeSize: holeSize
            )
            .equatable()
            .frame(size: vinylSize)
            .mask {
                Circle()
                    .frame(size: visibleSize)
            }
        }
        .frame(size: vinylSize)
        .contentShape(Circle())
        .onTapGesture {
            onTap?()
        }
        .transaction { $0.animation = nil }
    }

    // MARK: - Properties. Private

    private var shouldSpin: Bool {
        (isPlaying || isSeekScrubbing || isTapSpinning) && spinSpeed != 0
    }

    private var visibleSize: CGFloat {
        vinylSize - (vinylSize - coverSize) * progress
    }
}

// MARK: - VinylIdlePlate

private struct VinylIdlePlate: View, Equatable {

    let track: TrackEntity
    let isLoading: Bool
    let vinylSize: CGFloat
    let coverSize: CGFloat
    let holeSize: CGFloat

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.track.id == rhs.track.id
            && lhs.track.imagePath == rhs.track.imagePath
            && lhs.isLoading == rhs.isLoading
            && lhs.vinylSize == rhs.vinylSize
            && lhs.coverSize == rhs.coverSize
            && lhs.holeSize == rhs.holeSize
    }

    var body: some View {
        VinylPlateView(
            track: track,
            isLoading: isLoading,
            vinylImageSize: vinylSize,
            coverImageSize: coverSize,
            centerHoleSize: holeSize,
            rotation: 0
        )
    }
}

// MARK: - VinylSpinningDisc

private struct VinylSpinningDisc: View, Equatable {

    let track: TrackEntity
    let isLoading: Bool
    let isSpinning: Bool
    let spinDirection: Double
    let spinSpeed: Double
    let revolutionDuration: TimeInterval
    let vinylSize: CGFloat
    let coverSize: CGFloat
    let holeSize: CGFloat

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.track.id == rhs.track.id
            && lhs.track.imagePath == rhs.track.imagePath
            && lhs.isLoading == rhs.isLoading
            && lhs.isSpinning == rhs.isSpinning
            && lhs.spinDirection == rhs.spinDirection
            && lhs.spinSpeed == rhs.spinSpeed
            && lhs.revolutionDuration == rhs.revolutionDuration
            && lhs.vinylSize == rhs.vinylSize
            && lhs.coverSize == rhs.coverSize
            && lhs.holeSize == rhs.holeSize
    }

    var body: some View {
        VinylSpinHost(
            isSpinning: isSpinning,
            direction: spinDirection,
            speed: spinSpeed,
            revolutionDuration: revolutionDuration,
            size: vinylSize,
            contentKey: self.contentKey
        ) {
            VinylPlateView(
                track: track,
                isLoading: isLoading,
                vinylImageSize: vinylSize,
                coverImageSize: coverSize,
                centerHoleSize: holeSize,
                rotation: 0
            )
        }
    }

    private var contentKey: String {
        "\(track.id)|\(track.imagePath ?? "")|\(isLoading)|\(vinylSize)|\(coverSize)|\(holeSize)"
    }
}

// MARK: - VinylSpinHost

/// Rigid-body spin: the plate is flattened to a bitmap, clipped to a circle
/// about the rotation axis, then rotated with Core Animation. SwiftUI is not
/// in the rotating tree, so layout cannot change ω or the silhouette radius.
private struct VinylSpinHost<Content: View>: UIViewRepresentable {

    // MARK: - Properties. Public

    var isSpinning: Bool
    var direction: Double
    var speed: Double
    var revolutionDuration: TimeInterval
    var size: CGFloat
    var contentKey: String
    @ViewBuilder var content: () -> Content

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> VinylSpinContainer {
        let view = VinylSpinContainer()
        view.vinylSize = self.size
        view.setContent(self.content(), identity: self.contentKey)
        view.applySpin(
            isSpinning: self.isSpinning,
            direction: self.direction,
            speed: self.speed,
            duration: self.revolutionDuration
        )
        return view
    }

    func updateUIView(_ uiView: VinylSpinContainer, context: Context) {
        uiView.vinylSize = self.size
        uiView.setContent(self.content(), identity: self.contentKey)
        uiView.applySpin(
            isSpinning: self.isSpinning,
            direction: self.direction,
            speed: self.speed,
            duration: self.revolutionDuration
        )
    }
}

// MARK: - VinylSpinContainer

private final class VinylSpinContainer: UIView {

    // MARK: - Properties. Public

    var vinylSize: CGFloat = 0 {
        didSet {
            guard self.vinylSize != oldValue else { return }
            self.invalidateIntrinsicContentSize()
            self.applyCircleMask()
            self.renderPlateIfNeeded()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: self.vinylSize, height: self.vinylSize)
    }

    // MARK: - Initializer

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        self.clipsToBounds = true

        self.spinHost.backgroundColor = .clear
        self.spinHost.translatesAutoresizingMaskIntoConstraints = false
        self.spinHost.clipsToBounds = true
        self.addSubview(self.spinHost)

        self.plateView.contentMode = .scaleAspectFit
        self.plateView.backgroundColor = .clear
        self.plateView.translatesAutoresizingMaskIntoConstraints = false
        self.plateView.layer.shouldRasterize = true
        self.spinHost.addSubview(self.plateView)

        NSLayoutConstraint.activate([
            self.spinHost.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.spinHost.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.spinHost.topAnchor.constraint(equalTo: self.topAnchor),
            self.spinHost.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.plateView.leadingAnchor.constraint(equalTo: self.spinHost.leadingAnchor),
            self.plateView.trailingAnchor.constraint(equalTo: self.spinHost.trailingAnchor),
            self.plateView.topAnchor.constraint(equalTo: self.spinHost.topAnchor),
            self.plateView.bottomAnchor.constraint(equalTo: self.spinHost.bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        self.updateRasterizationScale()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.applyCircleMask()
        self.updateRasterizationScale()

        if self.plateView.image == nil {
            self.renderPlateIfNeeded()
        }
    }

    // MARK: - Methods. Public

    func setContent<Content: View>(_ view: Content, identity: String) {
        if identity == self.contentIdentity, self.plateView.image != nil {
            return
        }

        self.contentIdentity = identity
        self.pendingPlate = AnyView(view)
        self.renderPlateIfNeeded()
    }

    func applySpin(
        isSpinning: Bool,
        direction: Double,
        speed: Double,
        duration: TimeInterval
    ) {
        let spinning = isSpinning && speed != 0 && duration > 0
        let sameParams = self.lastSpinning == spinning
            && self.lastDirection == direction
            && abs(self.lastSpeed - speed) < 0.001
            && abs(self.lastDuration - duration) < 0.001

        guard sameParams.isFalse else { return }

        let angle = self.presentationRotation()
        self.spinHost.layer.removeAnimation(forKey: Self.spinKey)
        self.spinHost.layer.setValue(angle, forKeyPath: Self.rotationKeyPath)

        self.lastSpinning = spinning
        self.lastDirection = direction
        self.lastSpeed = speed
        self.lastDuration = duration

        guard spinning else { return }

        let turn = 2 * Double.pi * (direction >= 0 ? 1 : -1)
        let animation = CABasicAnimation(keyPath: Self.rotationKeyPath)
        animation.fromValue = angle
        animation.toValue = angle + turn
        animation.duration = duration / abs(speed)
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        self.spinHost.layer.add(animation, forKey: Self.spinKey)
    }

    // MARK: - Properties. Private

    private let spinHost = UIView()
    private let plateView = UIImageView()
    private var pendingPlate: AnyView?
    private var contentIdentity: String?
    private var lastSpinning = false
    private var lastDirection: Double = 1
    private var lastSpeed: Double = 1
    private var lastDuration: TimeInterval = 0

    private static let spinKey = "tunebox.vinyl.spin"
    private static let rotationKeyPath = "transform.rotation.z"

    // MARK: - Methods. Private

    private func applyCircleMask() {
        let side = min(self.bounds.width, self.bounds.height)
        let radius = (side > 0 ? side : self.vinylSize) / 2
        self.layer.cornerRadius = radius
        self.spinHost.layer.cornerRadius = radius
    }

    private func updateRasterizationScale() {
        self.plateView.layer.rasterizationScale = self.displayScale
    }

    private var displayScale: CGFloat {
        let scale = self.window?.windowScene?.screen.scale ?? self.traitCollection.displayScale

        return scale > 0 ? scale : 3
    }

    private func renderPlateIfNeeded() {
        guard let pendingPlate, self.vinylSize > 0 else { return }

        let size = self.vinylSize
        guard let image = self.snapshot(pendingPlate, size: size) else { return }

        self.plateView.image = image
        self.pendingPlate = nil
    }

    private func snapshot(_ view: AnyView, size: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size, height: size))
        renderer.scale = self.displayScale
        renderer.isOpaque = false
        renderer.proposedSize = ProposedViewSize(width: size, height: size)

        if let image = renderer.uiImage {
            return image
        }

        let host = UIHostingController(rootView: view.frame(width: size, height: size))
        host.safeAreaRegions = []
        host.view.bounds = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        host.view.backgroundColor = .clear
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = self.displayScale
        format.opaque = false

        return UIGraphicsImageRenderer(
            size: CGSize(width: size, height: size),
            format: format
        ).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
    }

    private func presentationRotation() -> Double {
        if let value = self.spinHost.layer.presentation()?.value(forKeyPath: Self.rotationKeyPath) as? NSNumber {
            return value.doubleValue
        }

        if let value = self.spinHost.layer.value(forKeyPath: Self.rotationKeyPath) as? NSNumber {
            return value.doubleValue
        }

        return 0
    }
}

#Preview {
    SpinningVinylView(
        track: TrackEntity(
            id: "1",
            image: nil,
            songName: "Get Lucky",
            duration: 369,
            artistName: "Daft Punk",
            albumName: "Random Access Memories",
            releaseDate: "2013",
            download: nil,
            waveformData: nil,
            size: 5_242_880
        ),
        isPlaying: false,
        isLoading: false,
        isSeekScrubbing: false,
        isTapSpinning: false,
        progress: 0.6,
        revolutionDuration: 2.5,
        spinDirection: 1,
        spinSpeed: 1,
        vinylSize: 240,
        coverSize: 96,
        holeSize: 8
    )
}
