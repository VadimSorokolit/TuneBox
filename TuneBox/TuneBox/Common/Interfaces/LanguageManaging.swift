//
//  LanguageManaging.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.09.2026.
//

import Foundation

@MainActor
protocol LanguageManaging: AnyObject {
    var language: AppLanguage { get }
    var locale: Locale { get }
    var refreshID: UUID { get }
    var menuOptions: [(AppLanguage, String)] { get }

    func setLanguage(_ language: AppLanguage)
}
