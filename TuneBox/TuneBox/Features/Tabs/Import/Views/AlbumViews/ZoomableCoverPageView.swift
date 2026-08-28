//
//  ZoomableCoverPageView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 12.08.2026.
//

import SwiftUI

struct ZoomableCoverPageView: View {

    // MARK: - Properties. Public

    let coverPath: String
    let isActive: Bool
    let onSingleTap: () -> Void

    // MARK: - Main Body

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            ZStack {
                CoverView(
                    coverPath: coverPath,
                    size: side,
                    cornerRadius: 0
                )
                .scaleEffect(currentScale)
                .offset(currentOffset)
                .gesture(magnifyGesture)
                .gesture(scale > 1 ? panGesture : nil)
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                        } else {
                            scale = 2.5
                        }
                    }
                }
                .onTapGesture(count: 1, perform: onSingleTap)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: isActive) { _, active in
            guard !active else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                scale = 1
                offset = .zero
            }
        }
    }

    // MARK: - Properties. Private

    @GestureState private var dragProgress: CGSize = .zero
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1
    @GestureState private var magnifyProgress: CGFloat = 1

    private var currentScale: CGFloat {
        max(1, scale * magnifyProgress)
    }

    private var currentOffset: CGSize {
        CGSize(
            width: offset.width + dragProgress.width,
            height: offset.height + dragProgress.height
        )
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($magnifyProgress) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let next = min(max(scale * value.magnification, 1), 4)
                withAnimation(.easeOut(duration: 0.2)) {
                    scale = next
                    if next <= 1 {
                        offset = .zero
                    }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($dragProgress) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                offset = CGSize(
                    width: offset.width + value.translation.width,
                    height: offset.height + value.translation.height
                )
            }
    }
}
