//
//  Track.swift
//  TuneBox
//
//  Created by Nintendo on 07.05.2026.
//

import Foundation

struct Track: Identifiable, Codable, Hashable {
    // API
    let id: String
    let imageURL: URL?
    let trackName: String
    let artistName: String
    let albumName: String
    let releaseDate: Date?
    let downloadURL: URL?
    // Custom
    var size: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL = "album_image"
        case trackName = "name"
        case artistName = "artist_name"
        case albumName = "album_name"
        case releaseDate = "releasedate"
        case downloadURL = "audiodownload"
    }
}
