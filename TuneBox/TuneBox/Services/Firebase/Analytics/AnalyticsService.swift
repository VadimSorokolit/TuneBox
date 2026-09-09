//
//  AnalyticsService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 09.09.2026.
//

import FirebaseAnalytics

final class AnalyticsService: AnalyticsServicing {

    func log(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters)
    }
}
