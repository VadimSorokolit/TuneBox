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
    let coverIndex: Int
    var onApplyBtnTap: ((Int) -> Void)?

    // MARK: - Initializer

    init(
        coverPaths: [String],
        coverIndex: Int,
        onApplyBtnTap: ((Int) -> Void)? = nil
    ) {
        self.coverPaths = coverPaths
        self.coverIndex = coverIndex
        self.onApplyBtnTap = onApplyBtnTap
    }

    // MARK: - Main Body

    var body: some View {
        ZStack {
            theme.tokens.appBackground.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(coverPaths.enumerated()), id: \.offset) { index, path in
                    ZoomableCoverPageView(
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
            currentIndex = coverIndex
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
                    onApplyBtnTap?(currentIndex)
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
