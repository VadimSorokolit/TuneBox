//
//  Int+formattedFileSize.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 15.07.2026.
//

import Foundation

extension Int {

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true

        return formatter.string(fromByteCount: Int64(self))
    }

}
