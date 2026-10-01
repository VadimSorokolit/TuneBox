//
//  TrackDownloadButton.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.10.2026.
//

import SwiftUI

struct TrackDownloadButton: View {

    // MARK: - Properties. Public

    let track: TrackEntity
    var size: CGFloat = GlobalConstants.TrackCell.actionButtonSize
    var iconSize: CGFloat = GlobalConstants.TrackCell.actionButtonIconSize
    var idleColor: Color = .black
    let action: () -> Void

    // MARK: - Main Body

    var body: some View {
        Button(action: action) {
            ZStack {
                if showsProgress {
                    Circle()
                        .stroke(Color.white, lineWidth: 0.8)

                    Circle()
                        .trim(from: 0, to: track.downloadingProgress)
                        .stroke(
                            Color.green,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }

                buttonImage
                    .font(.system(size: iconSize, weight: .medium))
            }
            .frame(size: size)
            .contentShape(Circle())
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Properties. Private

    private var showsProgress: Bool {
        track.downloadState != .completed && track.downloadState != .idle
    }

    @ViewBuilder
    private var buttonImage: some View {
        switch track.downloadState {
            case .idle:
                if track.fileState == .removed {
                    Image(systemName: "cloud")
                        .foregroundStyle(idleColor)
                } else {
                    Image(systemName: "arrow.down")
                        .foregroundStyle(idleColor)
                }

            case .queued:
                Image(systemName: "clock")
                    .foregroundStyle(Color.yellow)

            case .downloading:
                Image(systemName: "pause.fill")
                    .foregroundStyle(Color.red)

            case .paused:
                Image(systemName: "play.fill")
                    .foregroundStyle(Color.blue)

            case .completed:
                Image(systemName: "trash.fill")
                    .foregroundStyle(Color.red)

            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Color.orange)
        }
    }
}

#Preview {
    let track = TrackEntity(
        id: "1",
        image: nil,
        songName: "Believer",
        duration: 200,
        artistName: "Imagine Dragons",
        albumName: "Evolve",
        releaseDate: nil,
        download: nil,
        waveformData: nil,
        size: 5_242_880,
        downloadingSize: 2_000_000,
        downloadStateRawValue: DownloadState.downloading.rawValue
    )

    return TrackDownloadButton(track: track) {}
}
