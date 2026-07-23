//
//  PlaylistEntity.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 01.07.2026.
//

import Foundation
import SwiftData

enum PlaylistType: String {
    case system
    case custom
}

@Model
final class PlaylistEntity: Identifiable {
    @Attribute(.unique)
    var id: String
    var typeRawValue: String
    var title: String
    var coverImageData: Data?
    var tracks: [TrackEntity]
    var importSourceID: String?

    var type: PlaylistType {
        get {
            PlaylistType(rawValue: typeRawValue) ?? .custom
        }
        set {
            typeRawValue = newValue.rawValue
        }
    }

    init(
        id: String = UUID().uuidString,
        type: PlaylistType = .custom,
        title: String,
        isProtected: Bool = false,
        coverImageData: Data? = nil,
        tracks: [TrackEntity] = [],
        importSourceID: String? = nil
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.title = title
        self.coverImageData = coverImageData
        self.tracks = tracks
        self.importSourceID = importSourceID
    }
}
