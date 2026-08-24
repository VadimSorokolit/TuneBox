//
//  NetworkMonitoring.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 21.08.2026.
//

import Foundation

@MainActor
protocol NetworkMonitoring: AnyObject {
    var isConnected: Bool { get }
}
