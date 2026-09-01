//
//  EntitlementServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 31.08.2026.
//

import Foundation

@MainActor
protocol EntitlementServicing: AnyObject {
    var hasPremium: Bool { get }
    var localTrialStatus: LocalTrialStatus? { get }
    var paywallStatusMessage: String { get }

    func bootstrapLocalTrialIfNeeded()
    func refreshAccessState()
    func setHasPremium(_ value: Bool)

    #if DEBUG
    func debugExpireTrial()
    func debugResetTrial()
    #endif
}
