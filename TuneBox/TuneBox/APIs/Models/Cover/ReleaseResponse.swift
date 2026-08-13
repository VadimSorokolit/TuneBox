//
//  ReleaseResponse.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 13.08.2026.
//

import Foundation

struct ReleaseResponse: Decodable {
    let releases: [Release]

    struct Release: Decodable {
        let id: String
    }
}
