//
//  CoverPagerView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 11.08.2026.
//

import SwiftUI

struct CoverPagerView: View {

    // MARK: - Properties. Public

    let coverPaths: [String]
    let initialIndex: Int
    var onAppleBtnTap: ((Int) -> Void)?

    // MARK: - Initializer

    init(
        coverPaths: [String],
        initialIndex: Int,
        onAppleBtn: ((Int) -> Void)? = nil
    ) {
        self.coverPaths = coverPaths
        self.initialIndex = initialIndex
        self.onAppleBtnTap = onAppleBtn
    }

    // MARK: - Main Body

    var body: some View {
        ZStack {
            theme.tokens.appBackground.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(coverPaths.enumerated()), id: \.offset) { index, path in
                    ZoomableCoverPage(
                        coverPath: path,
                        isActive: index == currentIndex,
                        onSingleTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isControlsVisible.toggle()
                            }
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            if isControlsVisible {
                controls
                    .transition(.opacity)
            }
        }
        .statusBarHidden(!isControlsVisible)
        .onAppear {
            currentIndex = initialIndex
        }
    }

    // MARK: - Properties. Private

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var theme
    @State private var currentIndex = 0
    @State private var isControlsVisible = false

    private var controls: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial.opacity(0.35), in: Circle())
                }

                Spacer()

                Text("\(currentIndex + 1) of \(coverPaths.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: {
                    onAppleBtnTap?(currentIndex)
                    dismiss()
                }, label: {
                    Text("Apply")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial.opacity(0.35), in: Capsule())
                })
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Spacer()

            if coverPaths.count > 1, coverPaths.count <= 12 {
                pageIndicator
                    .padding(.bottom, 28)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(coverPaths.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.35))
                    .frame(
                        width: index == currentIndex ? 16 : 6,
                        height: 6
                    )
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
    }
}

private struct ZoomableCoverPage: View {

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
            .clipped()
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
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
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
