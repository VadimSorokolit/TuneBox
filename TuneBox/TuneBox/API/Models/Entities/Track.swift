//
//  Track.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.05.2026.
//

import Foundation

struct Track: Identifiable, Decodable, Hashable {
    
    // MARK: - API Properties
    
    let id: String
    let image: String?
    let trackName: String
    let artistName: String
    let albumName: String
    let releaseDate: String?
    let download: String?
    
    // MARK: Custom Properties
    
    var size: Int?
    var isDownloaded: Bool = false
    
    // MARK:  Computed Properties
    
    var imageURL: URL? {
        guard let image, !image.isEmpty else {
            return nil
        }
        
        return URL(string: image)
    }

    var downloadURL: URL? {
        guard let download, !download.isEmpty else {
            return nil
        }
        
        return URL(string: download)
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case image
        case trackName = "name"
        case artistName = "artist_name"
        case albumName = "album_name"
        case releaseDate = "releasedate"
        case download = "audiodownload"
    }
}
