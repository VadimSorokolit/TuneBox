//
//  VinylPlateView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 21.08.2026.
//

import SwiftUI

struct VinylPlateView: View {

    // MARK: - Properties. Public

    let track: TrackEntity
    let isLoading: Bool
    let vinylImageSize: CGFloat
    let coverImageSize: CGFloat
    let centerHoleSize: CGFloat
    let rotation: Double
    var onTap: (() -> Void)?

    // MARK: - Initializer

    init(
        track: TrackEntity,
        isLoading: Bool,
        vinylImageSize: CGFloat,
        coverImageSize: CGFloat,
        centerHoleSize: CGFloat,
        rotation: Double,
        onTap: (() -> Void)? = nil
    ) {
        self.track = track
        self.isLoading = isLoading
        self.vinylImageSize = vinylImageSize
        self.coverImageSize = coverImageSize
        self.centerHoleSize = centerHoleSize
        self.rotation = rotation
        self.onTap = onTap
    }

    // MARK: - Main Body

    var body: some View {
        ZStack {
            Image(.vinylPlate)
                .resizable()
                .scaledToFit()
                .clipShape(Circle())

            CoverView(
                coverPath: track.imagePath,
                size: coverImageSize,
                cornerRadius: coverImageSize / 2,
                placeholderOpacity: 1.0
            )
            .allowsHitTesting(false)

            Circle()
                .frame(size: centerHoleSize)
                .foregroundStyle(.black)
                .overlay {
                    Circle()
                        .stroke(.gray, lineWidth: 1)
                }

            if isLoading {
                SpinnerView(
                    size: .regular,
                    color: .gray
                )
            }
        }
        .frame(size: vinylImageSize)
        .rotationEffect(.degrees(rotation))
        .contentShape(Circle())
        .onTapGesture {
            onTap?()
        }
    }
}
