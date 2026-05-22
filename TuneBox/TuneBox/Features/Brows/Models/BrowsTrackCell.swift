//
//  BrowsTrackCell.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 19.05.2026.
//

import SwiftUI
import AVFoundation

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
    let onTap: () async -> Void

    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 10) {
                Text(id)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .frame(width: 90, alignment: .leading)
                    .padding(.leading, 10)

                if state == .completed {
                    Button(action: {
                        if isPlaying {
                            AudioService.shared.pause()
                        } else {
                            AudioService.shared.play(trackId: id)
                        }

                        isPlaying = AudioService.shared.isPlaying
                    }, label: {
                        Circle()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(Color.green)
                            .overlay(
                                Image(systemName: isPlaying
                                      ? "pause.fill"
                                      : "play.fill")
                            )
                            .foregroundStyle(Color.white)
                    })
                }

                if state == .failed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(Color.red)
                }
            }

            ProgressView(value: progress)
                .tint(buttonColor)
                .frame(maxWidth: .infinity)

            Button {
                Task {
                    await onTap()
                }
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .foregroundStyle(Color.gray.opacity(0.08))

        )
        .padding(.horizontal)
        .padding(.vertical, 10)
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
                return .black
            case .failed:
                return .red
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        BrowsTrackCell(
            id: "track_001",
            progress: 0.25,
            state: .downloading,
            onTap: { print("pause tapped") }
        )

        BrowsTrackCell(
            id: "track_002",
            progress: 0.0,
            state: .idle,
            onTap: { print("download tapped") }
        )

        BrowsTrackCell(
            id: "track_003",
            progress: 1.0,
            state: .completed,
            onTap: { print("delete tapped") }
        )
    }
    .padding()
}
