//
//  BrowsTrackCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 19.05.2026.
//

import SwiftUI

enum CellState {
    case idle
    case downloading
    case queued
    case paused
    case completed
    case failed
}

struct BrowsTrackCell: View {
    let id: String
    let progress: Double
    var state: CellState
    let onTap: () -> Void
    let onPlayTap: () -> Void
    let isPlaying: Bool
    let imageHeight: CGFloat = 20.0

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(id)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .frame(width: 60, alignment: .leading)
                    .padding(.leading, 10)

                if state == .completed {
                    Button(action: {
                        onPlayTap()
                    }, label: {
                        Circle()
                            .frame(width: imageHeight, height: imageHeight)
                            .foregroundStyle(Color.green)
                            .overlay(
                                Image(systemName: isPlaying
                                      ? "pause.fill"
                                      : "play.fill"
                                     )
                                .resizable()
                                .scaledToFit()
                                .frame(width: imageHeight - 10, height: imageHeight - 10)
                                .foregroundStyle(Color.white)
                            )
                    })
                } else if state == .failed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .frame(width: imageHeight, height: imageHeight)
                        .foregroundStyle(Color.red)
                } else {
                    Rectangle()
                        .frame(width: imageHeight, height: imageHeight)
                        .foregroundStyle(.clear)
                }
            }

            ProgressView(value: progress)
                .tint(.green)
                .frame(maxWidth: .infinity)

            Button {
                onTap()
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

            if state == .idle {}
        }
        .frame(height: 20)
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .foregroundStyle(Color.gray.opacity(0.08))

        )
    }

    private var buttonTitle: String {
        switch state {
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
        switch state {
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
                return Color(red: 0.85, green: 0.35, blue: 0.35)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        BrowsTrackCell(
            id: "track_001",
            progress: 0.25,
            state: .downloading,
            onTap: { print("pause tapped") },
            onPlayTap: {},
            isPlaying: false
        )

        BrowsTrackCell(
            id: "track_002",
            progress: 0.0,
            state: .idle,
            onTap: { print("download tapped") },
            onPlayTap: {},
            isPlaying: false
        )

        BrowsTrackCell(
            id: "track_003",
            progress: 1.0,
            state: .completed,
            onTap: { print("delete tapped") },
            onPlayTap: {},
            isPlaying: true
        )
    }
    .padding()
}
