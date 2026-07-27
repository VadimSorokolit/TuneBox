//
//  TrackAlphabetSection.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.07.2026.
//

struct TrackAlphabetSection: Identifiable {
    let letter: String
    let tracks: [TrackEntity]

    var id: String { letter }
}
