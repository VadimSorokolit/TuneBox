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

        let imageHeight: CGFloat = 20.0

        var body: some View {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Text(track.id)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .frame(width: 60, alignment: .leading)
                        .padding(.leading, 10)

                    if track.downloadState == .completed {
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
                    } else if track.downloadState == .failed {
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

                ProgressView(value: track.downloadingProgress)
                    .tint(.green)
                    .frame(maxWidth: .infinity)

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
            .frame(height: 20)
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(Color.gray.opacity(0.08))
            )
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
                    return Color(red: 0.85, green: 0.35, blue: 0.35)
            }
        }
    }

}

#Preview {
    func makeTrack(
        id: String,
        state: DownloadState,
        size: Int? = 100,
        downloadingSize: Int = 0,
        download: String? = nil
    ) -> TrackEntity {
        TrackEntity(
            id: id,
            image: nil,
            trackName: "Preview Track",
            artistName: "Preview Artist",
            albumName: "Preview Album",
            releaseDate: nil,
            download: download,
            waveformData: nil,
            size: size,
            downloadingSize: downloadingSize,
            downloadStateRawValue: state.rawValue
        )
    }

    return VStack(spacing: 12) {
        ContentView.TrackCell(
            track: makeTrack(
                id: "track_001",
                state: .downloading,
                downloadingSize: 45
            ),
            onDownloadTap: { print("pause tapped") },
            onPlayTap: {},
            isPlaying: false
        )

        ContentView.TrackCell(
            track: makeTrack(
                id: "track_002",
                state: .idle
            ),
            onDownloadTap: { print("download tapped") },
            onPlayTap: {},
            isPlaying: false
        )

        ContentView.TrackCell(
            track: makeTrack(
                id: "track_003",
                state: .completed,
                downloadingSize: 100,
                download: "local-file"
            ),
            onDownloadTap: { print("delete tapped") },
            onPlayTap: { print("play tapped") },
            isPlaying: true
        )
    }
    .padding()
}
