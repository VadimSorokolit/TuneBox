//
//  FeedbackSheetView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 24.09.2026.
//

import SwiftUI

struct FeedbackSheetView: View {

    // MARK: - Properties. Public

    let settingsVM: SettingsManaging
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
        .padding(.horizontal, 20)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.25), value: didSubmit)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .task {
            guard !didSubmit else { return }
            // Phone only: autofocus so keyboard rises with the sheet
            // On iPad simultaneous sheet + keyboard animation freezes
            guard !GlobalConstants.Device.isPad else { return }
            await Task.yield()
            isCommentFocused = true
        }
    }

    // MARK: - Properties. Private

    @FocusState private var isCommentFocused: Bool
    @State private var selectedRating: Satisfaction?
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorMessage: String?

    private var trimmedComment: String {
        comment.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        (selectedRating != nil || !trimmedComment.isEmpty) && !isSubmitting
    }

    private enum Satisfaction: Int, CaseIterable, Identifiable {
        case unhappy = 1
        case meh
        case okay
        case happy
        case loveIt

        var id: Int { rawValue }

        var emoji: String {
            switch self {
                case .unhappy:
                    "🙁"

                case .meh:
                    "😐"

                case .okay:
                    "🙂"

                case .happy:
                    "😊"

                case .loveIt:
                    "🤩"
            }
        }

        var label: String {
            switch self {
                case .unhappy:
                    L10n.Feedback.unhappy

                case .meh:
                    L10n.Feedback.meh

                case .okay:
                    L10n.Feedback.okay

                case .happy:
                    L10n.Feedback.happy

                case .loveIt:
                    L10n.Feedback.loveIt
            }
        }
    }

    private enum Constants {
        static let selectedScale: CGFloat = 1.16
        static let ringLineWidth: CGFloat = 1.5
        static let ratingEmojiSize: CGFloat = 34
        static let ratingButtonSize: CGFloat = 44
        static let ratingSpacing: CGFloat = 8
        static let disabledButtonOpacity: Double = 0.8
        static let successDisplayDuration: Duration = .milliseconds(1500)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Text(L10n.Feedback.prompt)
                .font(.body)
                .foregroundStyle(.primary)

            ratingRow

            TextField(
                L10n.Feedback.placeholder,
                text: $comment,
                axis: .vertical
            )
            .focused($isCommentFocused)
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
                        Text(L10n.Feedback.send)
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular.tint(Color.blue.opacity(canSubmit ? 0.28 : 0.12)).interactive(),
                in: .capsule
            )
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : Constants.disabledButtonOpacity)
        }
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)

            Text(L10n.Feedback.thanks)
                .font(.title2.weight(.semibold))

            Text(L10n.Feedback.thanksMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Text(L10n.Feedback.title)
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
        VStack(spacing: 10) {
            HStack(spacing: Constants.ratingSpacing) {
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
                    .accessibilityLabel(rating.label)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity)

            Text(selectedRating?.label ?? " ")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .opacity(selectedRating == nil ? 0 : 1)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.2), value: selectedRating)
        }
    }

    // MARK: - Methods. Private

    @MainActor
    private func submit() async {
        guard canSubmit else { return }

        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await settingsVM.submitFeedback(
                rating: selectedRating?.rawValue ?? 0,
                ratingLabel: selectedRating?.label ?? "",
                emoji: selectedRating?.emoji ?? "",
                comment: comment
            )
            didSubmit = true
            isCommentFocused = false
            try? await Task.sleep(for: Constants.successDisplayDuration)
            onClose()
        } catch {
            errorMessage = L10n.Feedback.sendError
        }
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            FeedbackSheetView(settingsVM: SettingsViewModel(), onClose: {})
        }
}
