//
//  LocalTrialStatus.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 01.09.2026.
//

import Foundation

enum LocalTrialStatus: Equatable {
    case active(until: Date)
    case expired(since: Date)

    var endDate: Date {
        switch self {
            case .active(until: let date),
                 .expired(since: let date):
                date
        }
    }

    var isActive: Bool {
        if case .active = self {
            return true
        }

        return false
    }
}

enum TrialConfiguration {
    static let duration: TimeInterval = 14 * 24 * 60 * 60
}
