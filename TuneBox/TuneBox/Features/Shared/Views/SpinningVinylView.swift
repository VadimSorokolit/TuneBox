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

    @State private var coverImage: UIImage?

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
                coverImage: coverImage,
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
                coverImage: coverImage,
                isLoading: isLoading,
                isSpinning: shouldSpin,
                ignoresSpinGate: isSeekScrubbing || isTapSpinning,
                spinDirection: spinDirection,
                spinSpeed: spinSpeed,
                revolutionDuration: revolutionDuration,
                visibleSize: visibleSize,
                vinylSize: vinylSize,
                coverSize: coverSize,
                holeSize: holeSize
            )
            .equatable()
            .frame(size: vinylSize)
        }
        .frame(size: vinylSize)
        .contentShape(Circle())
        .onTapGesture {
            onTap?()
        }
        .transaction { $0.animation = nil }
        .task(id: track.imagePath) {
            self.coverImage = nil
            self.coverImage = await CoverImageLoader.image(for: track.imagePath)
        }
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
    let coverImage: UIImage?
    let isLoading: Bool
    let vinylSize: CGFloat
    let coverSize: CGFloat
    let holeSize: CGFloat

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.track.id == rhs.track.id
            && lhs.track.imagePath == rhs.track.imagePath
            && lhs.coverImage === rhs.coverImage
            && lhs.isLoading == rhs.isLoading
            && lhs.vinylSize == rhs.vinylSize
            && lhs.coverSize == rhs.coverSize
            && lhs.holeSize == rhs.holeSize
    }

    var body: some View {
        VinylPlateView(
            track: track,
            coverImage: coverImage,
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
    let coverImage: UIImage?
    let isLoading: Bool
    let isSpinning: Bool
    let ignoresSpinGate: Bool
    let spinDirection: Double
    let spinSpeed: Double
    let revolutionDuration: TimeInterval
    let visibleSize: CGFloat
    let vinylSize: CGFloat
    let coverSize: CGFloat
    let holeSize: CGFloat

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.track.id == rhs.track.id
            && lhs.track.imagePath == rhs.track.imagePath
            && lhs.coverImage === rhs.coverImage
            && lhs.isLoading == rhs.isLoading
            && lhs.isSpinning == rhs.isSpinning
            && lhs.ignoresSpinGate == rhs.ignoresSpinGate
            && lhs.spinDirection == rhs.spinDirection
            && lhs.spinSpeed == rhs.spinSpeed
            && lhs.revolutionDuration == rhs.revolutionDuration
            && lhs.visibleSize == rhs.visibleSize
            && lhs.vinylSize == rhs.vinylSize
            && lhs.coverSize == rhs.coverSize
            && lhs.holeSize == rhs.holeSize
    }

    var body: some View {
        VinylSpinHost(
            isSpinning: isSpinning,
            ignoresSpinGate: ignoresSpinGate,
            direction: spinDirection,
            speed: spinSpeed,
            revolutionDuration: revolutionDuration,
            visibleSize: visibleSize,
            size: vinylSize,
            contentKey: self.contentKey
        ) {
            VinylPlateView(
                track: track,
                coverImage: coverImage,
                isLoading: isLoading,
                vinylImageSize: vinylSize,
                coverImageSize: coverSize,
                centerHoleSize: holeSize,
                rotation: 0
            )
        }
    }

    private var contentKey: String {
        "\(track.id)|\(track.imagePath ?? "")|\(coverImage != nil)|\(isLoading)|\(vinylSize)|\(coverSize)|\(holeSize)"
    }
}

// MARK: - VinylSpinHost

/// Rigid-body spin: the plate is flattened to a bitmap, clipped to a circle
/// about the rotation axis, then rotated with Core Animation. SwiftUI is not
/// in the rotating tree, so layout cannot change ω or the silhouette radius.
private struct VinylSpinHost<Content: View>: UIViewRepresentable {

    // MARK: - Properties. Public

    var isSpinning: Bool
    var ignoresSpinGate: Bool
    var direction: Double
    var speed: Double
    var revolutionDuration: TimeInterval
    var visibleSize: CGFloat
    var size: CGFloat
    var contentKey: String
    @ViewBuilder var content: () -> Content

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> VinylSpinContainer {
        let view = VinylSpinContainer()
        view.vinylSize = self.size
        view.visibleDiameter = self.visibleSize
        view.setContent(self.content(), identity: self.contentKey)
        view.applySpin(
            isSpinning: self.isSpinning,
            ignoresSpinGate: self.ignoresSpinGate,
            direction: self.direction,
            speed: self.speed,
            duration: self.revolutionDuration
        )
        return view
    }

    func updateUIView(_ uiView: VinylSpinContainer, context: Context) {
        uiView.vinylSize = self.size
        uiView.visibleDiameter = self.visibleSize
        uiView.setContent(self.content(), identity: self.contentKey)
        uiView.applySpin(
            isSpinning: self.isSpinning,
            ignoresSpinGate: self.ignoresSpinGate,
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
            self.updateShrinkMask()
            self.renderPlateIfNeeded()
        }
    }

    var visibleDiameter: CGFloat = 0 {
        didSet {
            guard self.visibleDiameter != oldValue else { return }
            self.updateShrinkMask()
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

        self.shrinkMask.fillColor = UIColor.white.cgColor
        self.layer.mask = self.shrinkMask

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

        self.routePauseObserver = NotificationCenter.default.addObserver(
            forName: .playbackDidPauseForRouteChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            VinylSpinGate.block()
            self?.stopSpinOnCurrentThread()
        }
        self.spinAllowObserver = NotificationCenter.default.addObserver(
            forName: .vinylSpinGateDidAllow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startSpinIfRequested()
        }
    }

    deinit {
        self.displayLink?.invalidate()
        if let routePauseObserver {
            NotificationCenter.default.removeObserver(routePauseObserver)
        }
        if let spinAllowObserver {
            NotificationCenter.default.removeObserver(spinAllowObserver)
        }
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
        self.updateShrinkMask()
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
        ignoresSpinGate: Bool,
        direction: Double,
        speed: Double,
        duration: TimeInterval
    ) {
        self.lastRequestedSpinning = isSpinning && speed != 0 && duration > 0
        self.lastIgnoresSpinGate = ignoresSpinGate

        let gateOK = VinylSpinGate.isAllowed || ignoresSpinGate

        if gateOK {
            self.suppressSpinUntilStopped = false
        } else if self.lastRequestedSpinning {
            self.suppressSpinUntilStopped = true
            self.lastSpinning = false
            self.lastDirection = direction
            self.lastSpeed = speed
            self.lastDuration = duration
            _ = self.haltSpinAnimation()
            return
        }

        if self.suppressSpinUntilStopped {
            if self.lastRequestedSpinning {
                self.lastSpinning = false
                self.lastDirection = direction
                self.lastSpeed = speed
                self.lastDuration = duration
                _ = self.haltSpinAnimation()
                return
            }

            self.suppressSpinUntilStopped = false
        }

        let spinning = self.lastRequestedSpinning && gateOK
        let sameParams = self.lastSpinning == spinning
            && self.lastDirection == direction
            && self.lastSpeed == speed
            && self.lastDuration == duration

        self.lastDirection = direction
        self.lastSpeed = speed
        self.lastDuration = duration

        guard sameParams.isFalse else { return }

        let angle = self.haltSpinAnimation()
        self.lastSpinning = spinning

        guard spinning else { return }

        self.startDisplayLink()
        self.startSpinAnimation(angle: angle, direction: direction, speed: speed, duration: duration)
    }

    private func startSpinIfRequested() {
        self.suppressSpinUntilStopped = false
        guard self.lastRequestedSpinning else { return }
        guard VinylSpinGate.isAllowed || self.lastIgnoresSpinGate else { return }

        self.applySpin(
            isSpinning: true,
            ignoresSpinGate: self.lastIgnoresSpinGate,
            direction: self.lastDirection,
            speed: self.lastSpeed,
            duration: self.lastDuration
        )
    }

    private func stopSpinOnCurrentThread() {
        if Thread.isMainThread {
            self.stopSpinImmediately()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.stopSpinImmediately()
            }
        }
    }

    private func stopSpinImmediately() {
        self.suppressSpinUntilStopped = true
        self.lastSpinning = false
        self.stopDisplayLink()
        _ = self.haltSpinAnimation()
    }

    @objc
    private func handleSpinGateTick() {
        guard VinylSpinGate.isAllowed.isFalse else { return }
        guard self.lastIgnoresSpinGate.isFalse else { return }
        self.stopSpinImmediately()
    }

    private func startDisplayLink() {
        guard self.displayLink == nil else { return }

        let link = CADisplayLink(target: self, selector: #selector(self.handleSpinGateTick))
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }

    private func stopDisplayLink() {
        self.displayLink?.invalidate()
        self.displayLink = nil
    }

    @discardableResult
    private func haltSpinAnimation() -> Double {
        self.stopDisplayLink()
        let angle = self.presentationRotation()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.spinHost.layer.removeAnimation(forKey: Self.spinKey)
        self.spinHost.layer.removeAllAnimations()
        self.spinHost.layer.setValue(angle, forKeyPath: Self.rotationKeyPath)
        CATransaction.commit()
        return angle
    }

    private func startSpinAnimation(
        angle: Double,
        direction: Double,
        speed: Double,
        duration: TimeInterval
    ) {
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
    private let shrinkMask = CAShapeLayer()
    private var pendingPlate: AnyView?
    private var contentIdentity: String?
    private var routePauseObserver: NSObjectProtocol?
    private var spinAllowObserver: NSObjectProtocol?
    private var displayLink: CADisplayLink?
    private var suppressSpinUntilStopped = false
    private var lastRequestedSpinning = false
    private var lastIgnoresSpinGate = false
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
        guard self.spinHost.layer.cornerRadius != radius else { return }
        self.spinHost.layer.cornerRadius = radius
    }

    private func updateShrinkMask() {
        let boundsSize = self.bounds.width > 0 ? self.bounds.width : self.vinylSize
        guard boundsSize > 0 else { return }

        let diameter = min(max(self.visibleDiameter > 0 ? self.visibleDiameter : boundsSize, 0), boundsSize)
        let origin = (boundsSize - diameter) / 2
        let rect = CGRect(x: origin, y: origin, width: diameter, height: diameter)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.shrinkMask.frame = CGRect(origin: .zero, size: CGSize(width: boundsSize, height: boundsSize))
        self.shrinkMask.path = CGPath(ellipseIn: rect, transform: nil)
        CATransaction.commit()
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
