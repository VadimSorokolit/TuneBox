//
//  SleepTimerSheetView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.09.2026.
//

import SwiftUI

struct SleepTimerSheetView: View {

    // MARK: - Properties. Public

    let settingsVM: SettingsManaging
    var onClose: () -> Void

    // MARK: - Main Body

    var body: some View {
        VStack(spacing: 24) {
            Text(L10n.Settings.sleepTimer)
                .font(.satoshi.bold.size(22))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if settingsVM.isSleepTimerActive {
                activeContent
            } else {
                pickerContent
            }

            Spacer(minLength: 0)

            actionButtons
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            guard settingsVM.isSleepTimerActive.isFalse else { return }

            hours = Self.defaultHours
            minutes = Self.defaultMinutes
        }
    }

    // MARK: - Properties. Private

    @State private var hours = Self.defaultHours
    @State private var minutes = Self.defaultMinutes

    private static let defaultHours = 0
    private static let defaultMinutes = 15

    private var canStart: Bool {
        hours > 0 || minutes > 0
    }

    // MARK: - Subviews. Private

    private var pickerContent: some View {
        HStack(spacing: 0) {
            Picker(L10n.Settings.sleepTimerHoursLabel, selection: $hours) {
                ForEach(0..<24, id: \.self) { value in
                    Text(L10n.Settings.sleepTimerHours(value))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker(L10n.Settings.sleepTimerMinutesLabel, selection: $minutes) {
                ForEach(0..<60, id: \.self) { value in
                    Text(L10n.Settings.sleepTimerMinutes(value))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 160)
    }

    private var activeContent: some View {
        VStack(spacing: 8) {
            Text(settingsVM.sleepTimerTrailingText)
                .font(.satoshi.bold.size(48))
                .foregroundStyle(.primary)
                .monospacedDigit()

            Text(L10n.Settings.sleepTimerHint)
                .font(.satoshi.regular.size(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                if settingsVM.isSleepTimerActive {
                    settingsVM.cancelSleepTimer()
                }
                onClose()
            }, label: {
                Text(L10n.Settings.sleepTimerCancel)
                    .font(.satoshi.medium.size(16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            })
            .buttonStyle(.bordered)
            .tint(.primary)

            if settingsVM.isSleepTimerActive.isFalse {
                Button(action: {
                    settingsVM.startSleepTimer(hours: hours, minutes: minutes)
                    onClose()
                }, label: {
                    Text(L10n.Settings.sleepTimerStart)
                        .font(.satoshi.medium.size(16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                })
                .buttonStyle(.borderedProminent)
                .disabled(canStart.isFalse)
            }
        }
    }
}

#Preview {
    SleepTimerSheetView(settingsVM: SettingsViewModel(), onClose: {})
}
