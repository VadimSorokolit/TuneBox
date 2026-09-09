//
//  CrashlyticsService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 09.09.2026.
//

import Foundation
import FirebaseCrashlytics

final class CrashlyticsService: CrashlyticsServicing {

    func record(_ error: Error, area: CrashlyticsArea) {
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(area.rawValue, forKey: "area")
        crashlytics.record(error: error)
    }
}
