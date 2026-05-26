//
//  Notification+value.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 26.05.2026.
//

import Foundation

extension Notification {

    func value<T>(for key: String) -> T? {
        self.userInfo?[key] as? T
    }

}
