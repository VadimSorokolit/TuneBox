//
//  FeedbackService.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 24.09.2026.
//

import FirebaseFirestore
import Foundation
import UIKit

final class FeedbackService: FeedbackServicing {

    func submit(
        rating: Int,
        ratingLabel: String,
        emoji: String,
        comment: String
    ) async throws {
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let systemVersion =
            "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        let appVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? ""
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? ""
        let languageCode = Locale.current.language.languageCode?.identifier ?? ""
        let preferredLanguage = Locale.preferredLanguages.first ?? ""
        let deviceRegionCode = Locale.current.region?.identifier ?? ""
        let timeZoneIdentifier = TimeZone.current.identifier
        let deviceModel = Self.deviceModelIdentifier

        let firestoreData: [String: Any] = [
            "rating": rating,
            "ratingLabel": ratingLabel,
            "emoji": emoji,
            "comment": trimmedComment,
            "systemName": Constants.systemName,
            "systemVersion": systemVersion,
            "appVersion": appVersion,
            "build": build,
            "languageCode": languageCode,
            "preferredLanguage": preferredLanguage,
            "deviceRegionCode": deviceRegionCode,
            "timeZone": timeZoneIdentifier,
            "deviceModel": deviceModel,
            "createdAt": FieldValue.serverTimestamp()
        ]

        // Primary store — must succeed.
        try await Firestore.firestore()
            .collection(Constants.collectionName)
            .addDocument(data: firestoreData)

        // Email notify — best effort; never fail the user flow.
        let message = """
        Feedback
        - Rating: \(rating) \(ratingLabel) \(emoji)
        - Comment: \(trimmedComment.isEmpty ? "—" : trimmedComment)

        App
        - Version: \(appVersion) (\(build))
        - System: \(Constants.systemName) \(systemVersion)
        - Device: \(displayOrDash(deviceModel))

        Locale
        - Language: \(displayOrDash(languageCode))
        - Preferred Language: \(displayOrDash(preferredLanguage))
        - Device Region: \(displayOrDash(deviceRegionCode))
        - Time Zone: \(displayOrDash(timeZoneIdentifier))
        """

        await sendWeb3FormsEmail(
            message: message,
            subject: "TuneBox Feedback — \(emoji) \(ratingLabel)"
        )
    }

    private func sendWeb3FormsEmail(message: String, subject: String) async {
        var request = URLRequest(url: Constants.web3FormsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload: [String: String] = [
            "access_key": Constants.web3FormsAccessKey,
            "subject": subject,
            "from_name": "TuneBox",
            "message": message
        ]

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            // Intentionally ignored — Firestore already saved the feedback.
        }
    }

    private func displayOrDash(_ value: String) -> String {
        value.isEmpty ? "—" : value
    }

    private static var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { machine in
                String(validatingUTF8: machine)
            }
        }
        return identifier ?? UIDevice.current.model
    }

    private enum Constants {
        static let collectionName = "feedback"
        static let web3FormsURL = URL(string: "https://api.web3forms.com/submit")!
        static let web3FormsAccessKey = "e998a93d-d45f-43fe-a017-22dde305a47a"

        static var systemName: String {
            #if os(iOS)
            "iOS"
            #elseif os(macOS)
            "macOS"
            #else
            "Unknown"
            #endif
        }
    }
}
