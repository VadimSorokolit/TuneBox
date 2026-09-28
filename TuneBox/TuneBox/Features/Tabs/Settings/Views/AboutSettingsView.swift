//
//  AboutSettingsView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.09.2026.
//

import SwiftUI
import UIKit

struct AboutSettingsView: View {

    // MARK: - Properties. Public

    let settingsVM: SettingsManaging
    @Binding var isFeedbackPresented: Bool

    // MARK: - Main Body

    var body: some View {
        Form {
            Section {
                SettingsRow(
                    title: L10n.Settings.license,
                    systemImage: "checkmark.seal.fill"
                ) {
                    settingsVM.presentPaywall()
                }

                SettingsRow(
                    title: L10n.Settings.shareFeedback,
                    systemImage: "square.and.pencil"
                ) {
                    isFeedbackPresented = true
                }

                SettingsRow(
                    title: L10n.Settings.share,
                    systemImage: "square.and.arrow.up"
                ) {
                    ActivitySharePresenter.present(
                        activityItems: settingsVM.shareActivityItems
                    )
                }

                SettingsRow(title: L10n.Settings.privacy) {
                    if let url = settingsVM.privacyPolicyURL {
                        openURL(url)
                    }
                }

                SettingsRow(title: L10n.Settings.terms) {
                    openURL(settingsVM.termsOfUseURL)
                }

                SettingsRow(
                    title: L10n.Settings.version,
                    value: settingsVM.marketingVersion,
                    showsSystemImage: false
                )
            }
        }
        .listSectionSpacing(.compact)
        .environment(\.defaultMinListRowHeight, 1)
        .customNavigationTitle(L10n.Settings.aboutTitle)
    }

    // MARK: - Properties. Private

    @Environment(\.openURL) private var openURL
}

#Preview {
    NavigationStack {
        AboutSettingsView(
            settingsVM: SettingsViewModel(),
            isFeedbackPresented: .constant(false)
        )
    }
}

@MainActor
private enum ActivitySharePresenter {

    static func present(activityItems: [Any]) {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        guard let presenter = topViewController() else { return }

        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(controller, animated: true)
    }

    private static func topViewController(
        base: UIViewController? = nil
    ) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController

        if let navigation = root as? UINavigationController {
            return topViewController(base: navigation.visibleViewController)
        }

        if let tabBar = root as? UITabBarController {
            return topViewController(base: tabBar.selectedViewController)
        }

        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }

        return root
    }
}
