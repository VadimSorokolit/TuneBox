//
//  TuneBoxRouter.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import Foundation
import os
import Moya

private struct Constants {
    static var apiKey: String {
        if let key = ProcessInfo.processInfo.environment["APIKey"] {
            return key
        } else {
            AppLogger.api.warning("Using mock API key")
            return "88888888"
        }
    }
}
