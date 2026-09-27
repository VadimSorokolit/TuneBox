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
        switch type {
            case .genre:
                L10n.Discover.featured
            case .popular:
                L10n.Discover.popular
            case .search:
                L10n.Discover.search
            case .recents:
                L10n.Discover.recents
            case .all:
                L10n.Discover.all
            case .imported:
                L10n.Discover.imported
        }
    }

    enum SectionType: String, Hashable {
        case genre
        case popular
        case search
        case recents
        case all
        case imported
    }
}
