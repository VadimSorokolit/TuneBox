//
//  FeedbackSheetView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 24.09.2026.
//

import SwiftUI
import UIKit

struct FeedbackSheetView: View {

    // MARK: - Properties. Public

    var onClose: () -> Void

    // MARK: - Main Body

    var body: some View {
        Group {
            if didSubmit {
                successContent
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                formContent
                    .transition(.opacity)
            }
        }
        .padding(20)
        .animation(.easeInOut(duration: 0.25), value: didSubmit)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Properties. Private

    @State private var selectedRating: Satisfaction = .neutral
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorMessage: String?

    private enum Satisfaction: Int, CaseIterable, Identifiable {
        case veryUnhappy = 1
        case unhappy
        case neutral
        case happy
        case veryHappy

        var id: Int { rawValue }

        var emoji: String {
            switch self {
                case .veryUnhappy:
                    "😠"

                case .unhappy:
                    "😕"

                case .neutral:
                    "😐"

                case .happy:
                    "🙂"

                case .veryHappy:
                    "😄"
            }
        }

        var label: String {
            switch self {
                case .veryUnhappy:
                    "Very Unhappy"

                case .unhappy:
                    "Unhappy"

                case .neutral:
                    "Neutral"

                case .happy:
                    "Happy"

                case .veryHappy:
                    "Very Happy"
            }
        }
    }

    private enum Constants {
        static let formURL = URL(string: "https://formspree.io/f/xqpabrba")!
        static let selectedScale: CGFloat = 1.18
        static let ringLineWidth: CGFloat = 1.5
        static let ratingEmojiSize: CGFloat = 42
        static let ratingButtonSize: CGFloat = 52
        static let successDisplayDuration: Duration = .milliseconds(1500)
    }

    private var commentPlaceholder: String {
        switch selectedRating {
            case .veryUnhappy, .unhappy, .neutral:
                "What made you not satisfied?"

            case .happy, .veryHappy:
                "What did you like?"
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Text("How satisfied are you with TuneBox?")
                .font(.body)
                .foregroundStyle(.primary)

            ratingRow

            TextField(
                commentPlaceholder,
                text: $comment,
                axis: .vertical
            )
            .lineLimit(4 ... 8)
            .padding(12)
            .font(.system(size: 20))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await submit() }
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Send Feedback")
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular.tint(Color.blue.opacity(0.28)).interactive(),
                in: .capsule
            )
            .disabled(isSubmitting)
        }
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)

            Text("Thanks!")
                .font(.title2.weight(.semibold))

            Text("Your feedback helps make TuneBox better.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Text("SHARE YOUR FEEDBACK")
                .font(.headline)
                .fontWeight(.medium)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(size: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var ratingRow: some View {
        HStack(spacing: 12) {
            ForEach(Satisfaction.allCases) { rating in
                let isSelected = selectedRating == rating

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        selectedRating = rating
                    }
                } label: {
                    Text(rating.emoji)
                        .font(.system(size: Constants.ratingEmojiSize))
                        .frame(size: Constants.ratingButtonSize)
                        .scaleEffect(isSelected ? Constants.selectedScale : 1)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isSelected ? Color.primary.opacity(0.35) : Color.clear,
                                    lineWidth: Constants.ringLineWidth
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Methods. Private

    @MainActor
    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        var request = URLRequest(url: Constants.formURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload: [String: String] = [
            "rating": String(selectedRating.rawValue),
            "ratingLabel": selectedRating.label,
            "emoji": selectedRating.emoji,
            "comment": comment.trimmingCharacters(in: .whitespacesAndNewlines),
            "model": UIDevice.current.model,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "",
            "build": Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? ""
        ]

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode) else {
                errorMessage = "Couldn't send feedback. Try again."
                return
            }

            didSubmit = true
            try? await Task.sleep(for: Constants.successDisplayDuration)
            onClose()
        } catch {
            errorMessage = "Couldn't send feedback. Try again."
        }
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            FeedbackSheetView(onClose: {})
        }
}
