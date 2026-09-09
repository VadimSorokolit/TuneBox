//
//  CrashlyticsServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 09.09.2026.
//

import Foundation

enum CrashlyticsArea: String {
    case player = "play_start"
    case importFolder = "import_folder"
    case download = "download_complete"
    case purchase = "purchase"
}

@MainActor
protocol CrashlyticsServicing: AnyObject {
    func record(_ error: Error, area: CrashlyticsArea)
}
