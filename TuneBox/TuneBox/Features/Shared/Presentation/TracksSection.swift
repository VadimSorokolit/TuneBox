//
//  TracksSection.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.06.2026.
//

import Foundation

struct TracksSection: Hashable, Identifiable {
    let type: SectionType
    var tracks: [TrackEntity]

    var id: SectionType {
        type
    }

    var title: String {
        type.rawValue
    }

    enum SectionType: String, Hashable {
        case genre = "Featured"
        case popular = "Popular"
        case search = "Search"
        case recents = "Recents"
        case all = "All"
        case imported = "Imported"
    }
}
