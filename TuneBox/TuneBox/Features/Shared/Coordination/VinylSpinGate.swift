//
//  VinylSpinGate.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.09.2026.
//

import Foundation

enum VinylSpinGate {
    static var isAllowed: Bool {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return Self.allowed
    }

    static func allow() {
        Self.lock.lock()
        Self.allowed = true
        Self.lock.unlock()
        NotificationCenter.default.post(name: .vinylSpinGateDidAllow, object: nil)
    }

    static func block() {
        Self.lock.lock()
        Self.allowed = false
        Self.lock.unlock()
    }

    private static let lock = NSLock()
    private static var allowed = false
}
