//
//  Int+formattedDuration.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

extension Int {

    var formattedDuration: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60

        return hours > 0
        ? "\(hours) hours \(minutes) minutes \(seconds) seconds"
        : "\(minutes) minutes \(seconds) seconds"
    }

}
