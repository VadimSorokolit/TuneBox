//
//  AlbumTracksView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import SwiftUI
import Resolver

struct AlbumDetailsView: View {

    // MARK: - Properties. Public

    let album: MusicLibrary.Album?

    // MARK: - Main Body

    var body: some View {
        if let album {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ArtworkView(artworkPath: album.cover,
                                size: 300,
                                cornerRadius: 5
                    )

                    LazyVStack(spacing: 0) {
                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                            NumberedTrackCell(
                                index: index + 1,
                                track: track,
                                isPlaying: selectedTrack == track,
                                onTapGesture: {
                                    selectedTrack = track
                                    playerViewModel.handlePlayAction(for: track)
                                }
                            )
                        }
                    }

                    LibrarySummaryFooter(
                        count: album.tracks.count,
                        unitSingular: "track",
                        unitPlural: "tracks",
                        duration: viewModel.tracksDuration(album.tracks),
                        size: viewModel.tracksSize(album.tracks)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentMargins(.bottom, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: album.artist.isEmpty ? 0 : 2) {
                        if album.artist.isNotEmpty {
                            Text(album.artist)
                                .lineLimit(1)
                                .font(.caption)
                        }

                        Text(album.name)
                            .lineLimit(album.artist.isEmpty ? 2 : 1)
                            .font(.headline)
                    }
                    .frame(width: 200, alignment: .center)
                }
            }
            .safeAreaInset(edge: .bottom) {
                    if selectedTrack != nil {
                        CompactPlayerView(
                            track: selectedTrack,
                            isPlaying: selectedTrack.map { playerViewModel.isPlaying($0) } ?? false,
                            progress: playerViewModel.progress,
                            onRewindTap: {
                                AudioService.shared.seek(by: -10)
                            }, onPlayPauseTap: {
                                guard let track = selectedTrack else { return }
                                playerViewModel.handlePlayAction(for: track)
                            }, onForwardTap: {
                                AudioService.shared.seek(by: 10)
                            },
                            onProgressTap: {
                                isShowingExpandedPlayer = true
                            }
                        )
                        .padding(.bottom, 20)
                    }
            }
            .sheet(isPresented: $isShowingExpandedPlayer) {
                Text("Expanded player")
            }
            .animation(.easeInOut(duration: 0.25), value: isShowingExpandedPlayer)
        }
    }

    // MARK: - Properties. Private

    @Injected private var viewModel: ImportManaging
    @Injected private var playerViewModel: PlayerManaging
    @State private var isShowingExpandedPlayer: Bool = false
    @State private var selectedTrack: TrackEntity?
}
