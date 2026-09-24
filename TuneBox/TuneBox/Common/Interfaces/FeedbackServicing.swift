//
//  FeedbackServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 24.09.2026.
//

import Foundation

@MainActor
protocol FeedbackServicing: AnyObject {
    func submit(
        rating: Int,
        ratingLabel: String,
        emoji: String,
        comment: String
    ) async throws
}
