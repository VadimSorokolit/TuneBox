//
//  PlaybackSessionSnapshot.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.08.2026.
//

import Foundation

enum PlaybackOriginSnapshot: Codable, Equatable {
    case album(id: String)
    case artist(id: String)
    case sourceFolder(sourceID: UUID, path: String?)
    case playlist(id: String, title: String)
    case tracksLibrary(title: String?)
    case downloads
}

struct PlaybackSessionSnapshot: Codable, Equatable {
    var trackID: String
    var progress: Double
    var queueTrackIDs: [String]
    var origin: PlaybackOriginSnapshot?
}

extension PlaybackOriginSnapshot {

    init?(from path: [AppRoute]) {
        guard let last = path.last else { return nil }

        switch last {
            case .sourceFolder(let id, let folderPath):
                self = .sourceFolder(sourceID: id, path: folderPath)

            case .album(let album):
                self = .album(id: album.id)

            case .artist(let artist):
                self = .artist(id: artist.id)

            case .tracks(let title, .library):
                self = .tracksLibrary(title: title)

            case .tracks(_, .downloads):
                self = .downloads

            case .tracks(let title, .fixed):
                let fromPlaylists = path.contains {
                    if case .playlists = $0 { return true }
                    return false
                }
                guard fromPlaylists else { return nil }
                let name = title ?? ""
                self = .playlist(id: name, title: name)

            default:
                return nil
        }
    }

}
