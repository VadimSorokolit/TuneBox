//
//  DownloadsPresenting.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.06.2026.
//

protocol DownloadsPresenting {
    var sections: [TracksSection] { get }

    func fetchTracksSection() 
}
