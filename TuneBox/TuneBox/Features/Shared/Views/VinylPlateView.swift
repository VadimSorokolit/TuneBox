//
//  Untitled.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 21.08.2026.
//

import SwiftUI

struct VinylPlateView: View {

    let track: TrackEntity
    let isLoading: Bool
    let vinylImageSize: CGFloat
    let coverImageSize: CGFloat
    let centerHoleSize: CGFloat
    let rotation: Double

    var body: some View {
        ZStack {
            Image(.vinylPlate)
                .resizable()
                .scaledToFit()
                .clipShape(Circle())

            CoverView(
                coverPath: track.imagePath,
                size: coverImageSize,
                cornerRadius: coverImageSize / 2
            )

            Circle()
                .frame(size: centerHoleSize)
                .foregroundColor(.black)

            if isLoading {
                SpinnerView(
                    size: .regular,
                    color: .gray
                )
            }
        }
        .frame(size: vinylImageSize)
        .rotationEffect(.degrees(rotation))
    }
}
