//
//  LanguageServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.09.2026.
//

import Foundation

@MainActor
protocol LanguageServicing: AnyObject {
    var selectedLanguage: AppLanguage { get }
    var resolvedCode: String { get }
    var locale: Locale { get }

    func setLanguage(_ language: AppLanguage)
}
