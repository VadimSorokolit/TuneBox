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
}
