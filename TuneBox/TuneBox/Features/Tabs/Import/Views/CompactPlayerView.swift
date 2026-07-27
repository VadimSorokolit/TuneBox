//
//  CompactPlayerView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 10.07.2026.
//

import SwiftUI

struct CompactPlayerView: View {

    // MARK: - Properties. Public

    let track: TrackEntity?
    var isPlaying: Bool
    var progress: Double
    let onRewindTap: () -> Void
    let onPlayPauseTap: () -> Void
    let onForwardTap: () -> Void
    let onProgressTap: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 12) {
                ArtworkView(
                    artworkPath: track?.imagePath,
                    size: 44,
                    cornerRadius: 8
                )

                VStack(alignment: .leading, spacing: track?.artistName.isEmpty == true ? 0 : 2) {
                    Text(track?.songName ?? "")
                        .font(.headline)
                        .lineLimit(1)

                    Text(track?.artistName ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        onRewindTap()
                    } label: {
                        Image(systemName: "gobackward.10")
                            .frame(size: imageSize)
                    }
                    .disabled(progress == 0)

                    Button {
                        onPlayPauseTap()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .frame(size: imageSize)
                    }

                    Button {
                        onForwardTap()
                    } label: {
                        Image(systemName: "goforward.10")
                            .frame(size: imageSize)
                    }
                    .disabled(progress == 1)
                }
                .font(.title3)
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .frame(maxWidth: .infinity)

            ZStack {
                GeometryReader { geo in
                    Capsule()
                        .fill(.orange)
                        .frame(width: geo.size.width * min(max(progress, 0), 1), height: 3)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }

                Button(action: {
                    onProgressTap()
                }, label: {
                    Color.clear
                        .frame(maxHeight: .infinity)
                })
            }
            .frame(height: 15)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .glassEffect(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    // MARK: - Properties. Private

    private let imageSize: CGFloat = 40
}

#Preview {
    CompactPlayerView(
        track: TrackEntity(
            id: "1",
            image: "https://usercontent.jamendo.com/?type=album&id=24&width=300&trackid=168",
            songName: "Believer",
            duration: 200,
            artistName: "Imagine Dragons",
            albumName: "Evolve",
            releaseDate: "2017-02-01",
            download: nil,
            waveformData: nil,
            size: 5_242_880
        ),
        isPlaying: true,
        progress: 0.5,
        onRewindTap: {},
        onPlayPauseTap: {},
        onForwardTap: {},
        onProgressTap: {}
    )
}
