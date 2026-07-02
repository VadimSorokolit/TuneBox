//
//  PlaylistEntity.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 01.07.2026.
//

import Foundation
import SwiftData

@Model
final class PlaylistEntity: Identifiable {
    @Attribute(.unique)
    var id: String
    var title: String
    var coverImageData: Data?

    var tracks: [TrackEntity]

    init(
        id: String = UUID().uuidString,
        name: String,
        isProtected: Bool = false,
        coverImageData: Data? = nil,
        tracks: [TrackEntity] = []
    ) {
        self.id = id
        self.title = name
        self.coverImageData = coverImageData
        self.tracks = tracks
    }
}
