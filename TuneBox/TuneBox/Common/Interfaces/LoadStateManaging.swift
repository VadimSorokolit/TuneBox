//
//  LoadStateManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.07.2026.
//

protocol LoadStateManaging: AnyObject {
    var isLoading: Bool { get }
    var error: String? { get }
}
