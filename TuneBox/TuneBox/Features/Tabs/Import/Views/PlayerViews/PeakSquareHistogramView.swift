//
//  PeakSquareHistogramView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.09.2026.
//

import SwiftUI

struct PeakSquareHistogramView: View {

    // MARK: - Properties. Public

    let bands: [Float]
    var bandCount: Int
    let centers: [Float]
    var isActive: Bool

    // MARK: - Main Body

    var body: some View {
        GeometryReader { geometry in
            let displayBands = normalizedBands(bands, count: bandCount)
            let layout = HistogramLayout(
                columnCount: bandCount,
                totalWidth: geometry.size.width,
                columnSpacing: columnSpacing,
                maxStackHeight: maxStackHeight
            )

            HStack(alignment: .bottom, spacing: columnSpacing) {
                ForEach(0 ..< bandCount, id: \.self) { index in
                    HistogramBandSlot(
                        level: isActive ? displayBands[index] : 0,
                        color: spectrumColor(bandIndex: index),
                        dotSize: layout.dotSize,
                        stackHeight: layout.stackHeight,
                        columnWidth: layout.columnWidth,
                        maxStackHeight: maxStackHeight
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: layout.stackHeight, alignment: .bottom)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: - Properties. Private

    private let maxStackHeight = 14
    private let columnSpacing: CGFloat = 3

    // MARK: - Methods. Private

    private func normalizedBands(_ bands: [Float], count: Int) -> [Float] {
        if bands.count == count {
            return bands
        }

        if bands.isEmpty {
            return [Float](repeating: 0, count: count)
        }

        if bands.count > count {
            return Array(bands.prefix(count))
        }

        return bands + [Float](repeating: 0, count: count - bands.count)
    }

    private func spectrumColor(bandIndex: Int) -> Color {
        let frequency = centers.indices.contains(bandIndex) ? centers[bandIndex] : 1_000

        // 3-way listener split: bass / mids / treble.
        // 250 Hz and 2 kHz belong to the lower group, not the next one.
        if frequency <= 250 {
            return .green
        }

        if frequency <= 2_000 {
            return .yellow
        }

        return .red
    }

    // MARK: - Objects. Private

    private struct HistogramLayout {
        let columnWidth: CGFloat
        let dotSize: CGFloat
        let stackHeight: CGFloat

        init(
            columnCount: Int,
            totalWidth: CGFloat,
            columnSpacing: CGFloat,
            maxStackHeight: Int
        ) {
            guard columnCount > 0 else {
                self.columnWidth = 0
                self.dotSize = 0
                self.stackHeight = 0
                return
            }

            let spacingTotal = columnSpacing * CGFloat(max(0, columnCount - 1))
            let columnsWidth = max(0, totalWidth - spacingTotal)
            self.columnWidth = max(3, columnsWidth / CGFloat(columnCount))
            self.dotSize = min(columnWidth * 0.72, 8)
            self.stackHeight = CGFloat(maxStackHeight) * dotSize
                + CGFloat(max(0, maxStackHeight - 1)) * 2
        }
    }

    private struct HistogramBandSlot: View {

        // MARK: - Properties. Public

        let level: Float
        let color: Color
        let dotSize: CGFloat
        let stackHeight: CGFloat
        let columnWidth: CGFloat
        let maxStackHeight: Int

        // MARK: - Body

        var body: some View {
            let filledCount = filledDotCount()

            VStack(spacing: 2) {
                ForEach((0 ..< maxStackHeight).reversed(), id: \.self) { row in
                    Circle()
                        .fill(color)
                        .frame(width: dotSize, height: dotSize)
                        .opacity(row < filledCount ? 1 : 0)
                }
            }
            .animation(.easeOut(duration: 0.08), value: filledCount)
            .frame(width: columnWidth, height: stackHeight, alignment: .bottom)
            .accessibilityHidden(filledCount == 0)
        }

        // MARK: - Methods. Private

        private func filledDotCount() -> Int {
            let count = Int((max(0, level) * Float(maxStackHeight)).rounded())

            return min(maxStackHeight, max(0, count))
        }
    }

}
