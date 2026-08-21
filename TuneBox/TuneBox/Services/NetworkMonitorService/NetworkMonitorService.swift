//
//  NetworkMonitorService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 21.08.2026.
//

import Foundation
import Network
import Observation

@MainActor
@Observable
final class NetworkMonitorService: NetworkMonitoring {

    // MARK: - Singleton

    static let shared = NetworkMonitorService()

    // MARK: - Properties. Public

    private(set) var isConnected: Bool = false

    // MARK: - Initializer

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied

            Task { @MainActor [weak self] in
                self?.isConnected = isConnected
            }
        }
        monitor.start(queue: self.queue)
    }

    // MARK: - Deinitializer

    deinit {
        self.monitor.cancel()
    }

    // MARK: - Properties. Private

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "network.monitor")
}
