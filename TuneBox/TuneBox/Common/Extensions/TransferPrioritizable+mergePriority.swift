//
//  TransferPrioritizable+mergePriority.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 02.06.2026.
//

extension TransferPrioritizable {

    func merged(with other: Self) -> Self {
        mergePriority >= other.mergePriority ? self : other
    }

}
