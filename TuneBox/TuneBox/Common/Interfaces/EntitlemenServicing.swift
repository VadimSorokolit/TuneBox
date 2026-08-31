//
//  EntitlemenServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.08.2026.
//

import Foundation

@MainActor
protocol EntitlementServicing: AnyObject {
    var hasPremium: Bool { get }

    func setHasPremium(_ value: Bool)
}
