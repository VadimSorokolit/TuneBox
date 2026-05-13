//
//  AppLogger.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import Foundation
import os

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "App"
    static let api = Logger(subsystem: subsystem, category: "API")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let transfer = Logger(subsystem: subsystem, category: "Transfer")
}
