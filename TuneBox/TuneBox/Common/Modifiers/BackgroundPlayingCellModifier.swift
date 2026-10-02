//
//  BackgroundPlayingCellModifier.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.09.2026.
//

import SwiftUI

struct BackgroundPlayingCellModifier: ViewModifier {

    let isPlaying: Bool

    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .background {
                if isPlaying {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.gray.opacity(0.1))
                        .overlay {
                            GeometryReader { proxy in
                                let side = hypot(proxy.size.width, proxy.size.height)

                                AngularGradient(
                                    colors: [
                                        .clear,
                                        .primary.opacity(0.45),
                                        .clear
                                    ],
                                    center: .center
                                )
                                .frame(width: side, height: side)
                                .rotationEffect(.degrees(rotation))
                                .frame(width: proxy.size.width, height: proxy.size.height)
                            }
                            .mask {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(lineWidth: 0.35)
                            }
                        }
                        .padding(.horizontal, 8)
                        .onAppear {
                            rotation = 0
                            withAnimation(
                                .linear(duration: 2.0)
                                    .repeatForever(autoreverses: false)
                            ) {
                                rotation = 360
                            }
                        }
                }
            }
    }
}
