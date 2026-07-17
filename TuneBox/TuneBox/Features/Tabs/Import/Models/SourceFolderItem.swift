//
//  SourceFolderItem.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 17.07.2026.
//

import Foundation

struct SourceFolderItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case folder
        case track
        case playlist
    }

    let url: URL
    let kind: Kind

    var id: URL { url }
}
