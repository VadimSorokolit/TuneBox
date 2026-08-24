//
//  Optional+Extensions.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 24.08.2026.
//

extension Optional {

    var isNotNil: Bool {
        self != nil
    }
    
    var isNil: Bool {
        self == nil
    }

}
