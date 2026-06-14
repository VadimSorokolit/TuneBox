//
//  TracksSection.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.06.2026.
//

import Foundation

struct TracksSection: Hashable, Identifiable {
    let id: UUID = UUID()
    let type: SectionType
    let title: String
    var tracks: [TrackEntity]

    enum SectionType: String {
        case genre = "Featured"
        case popular = "Popular"
        case search = "Search"
        case activeDownloads = "Active Downloads"
        case downloaded = "Downloaded"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TracksSection, rhs: TracksSection) -> Bool {
        lhs.id == rhs.id
    }
}
