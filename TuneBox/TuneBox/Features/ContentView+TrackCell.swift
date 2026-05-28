//
//  ContentView+TrackCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 19.05.2026.
//

import SwiftUI

extension ContentView {

    struct TrackCell: View {
        let track: TrackEntity
        let onDownloadTap: () -> Void
        let onPlayTap: () -> Void
        let isPlaying: Bool

        @State private var displayedProgress: Double = 0

        private let imageHeight: CGFloat = 20.0

        var body: some View {
            HStack(spacing: 12) {
                leadingSection

                progressSection

                actionButton
            }
            .frame(height: 20)
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(Color.gray.opacity(0.08))
            )
        }

        private var leadingSection: some View {
            HStack(spacing: 10) {

                Text(track.id)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .frame(width: 60, alignment: .leading)
                    .padding(.leading, 10)

                iconView
            }
        }

        @ViewBuilder
        private var progressSection: some View {
            if shouldShowProgress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {

                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                        
                        Capsule()
                            .fill(Color.green)
                            .frame(
                                width: geometry.size.width * track.downloadingProgress
                            )
                    }
                }
                .frame(height: 4)
                .frame(maxWidth: .infinity)
                .animation(
                    track.downloadState == .downloading
                    ? .linear(duration: 0.2)
                    : nil,
                    value: track.downloadingProgress
                )
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }

        private var actionButton: some View {
            Button {
                onDownloadTap()
            } label: {
                Text(buttonTitle)
                    .font(.system(size: 12))
                    .frame(minWidth: 70)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(buttonColor.opacity(0.15))
                    .foregroundColor(buttonColor)
                    .clipShape(Capsule())
            }
        }

        @ViewBuilder
        private var iconView: some View {
            switch track.downloadState {
                case .completed:
                    Button(action: {
                        onPlayTap()
                    }, label: {
                        Circle()
                            .frame(
                                width: imageHeight,
                                height: imageHeight
                            )
                            .foregroundStyle(Color.green)
                            .overlay(
                                Image(
                                    systemName: isPlaying
                                    ? "pause.fill"
                                    : "play.fill"
                                )
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    width: imageHeight - 10,
                                    height: imageHeight - 10
                                )
                                .foregroundStyle(Color.white)
                            )
                    })

                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .frame(
                            width: imageHeight,
                            height: imageHeight
                        )
                        .foregroundStyle(Color.red)

                default:
                    Rectangle()
                        .frame(
                            width: imageHeight,
                            height: imageHeight
                        )
                        .foregroundStyle(.clear)
            }
        }

        private var shouldShowProgress: Bool {
            switch track.downloadState {
                case .downloading,
                     .paused,
                     .queued:
                    return true

                default:
                    return false
            }
        }

        private var buttonTitle: String {
            switch track.downloadState {
                case .idle:
                    return "Download"

                case .downloading:
                    return "Pause"

                case .queued:
                    return "Cancel"

                case .paused:
                    return "Resume"

                case .completed:
                    return "Delete"

                case .failed:
                    return "Failed"
            }
        }

        private var buttonColor: Color {
            switch track.downloadState {
                case .idle:
                    return .blue

                case .downloading:
                    return .orange

                case .queued:
                    return .purple

                case .paused:
                    return .green

                case .completed:
                    return .red

                case .failed:
                    return Color(
                        red: 0.85,
                        green: 0.35,
                        blue: 0.35
                    )
            }
        }
    }
}
