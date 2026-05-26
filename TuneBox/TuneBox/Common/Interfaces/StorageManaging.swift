//
//  StorageManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.05.2026.
//

import Foundation

protocol StorageManaging: AnyObject {
    var availableSpace: Double? { get }
    var reservedSpace: ReservedSpace { get }
    var simultaneouslyLoadingCount: Int { get }

    func applyReservedSpace(_ plan: ReservedSpace)
}
