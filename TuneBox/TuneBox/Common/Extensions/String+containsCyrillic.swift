//
//  String+containsCyrillic.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.10.2026.
//

import Foundation

extension String {

    var containsCyrillic: Bool {
        unicodeScalars.contains { scalar in
            (0x0400...0x04FF).contains(scalar.value)
            || (0x0500...0x052F).contains(scalar.value)
        }
    }

}
