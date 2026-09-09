//
//  AnalyticsServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 09.09.2026.
//

import Foundation

enum AnalyticsEvent {
    case playStart(source: String, format: String)
    case importFolder(success: Bool, trackCount: Int)
    case downloadComplete
    case paywallView
    case purchase(product: String, success: Bool)

    var name: String {
        switch self {
            case .playStart:
                "play_start"

            case .importFolder:
                "import_folder"

            case .downloadComplete:
                "download_complete"

            case .paywallView:
                "paywall_view"

            case .purchase:
                "purchase"
        }
    }

    var parameters: [String: Any]? {
        switch self {
            case .playStart(let source, let format):
                [
                    "source": source,
                    "format": format
                ]

            case .importFolder(let success, let trackCount):
                [
                    "success": success,
                    "track_count": trackCount
                ]

            case .downloadComplete, .paywallView:
                nil

            case .purchase(let product, let success):
                [
                    "product": product,
                    "success": success
                ]
        }
    }
}

@MainActor
protocol AnalyticsServicing: AnyObject {
    func log(_ event: AnalyticsEvent)
}
