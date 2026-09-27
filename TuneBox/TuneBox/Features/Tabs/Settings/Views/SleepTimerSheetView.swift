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
            Text("Sleep Timer")
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
            Picker("Hours", selection: $hours) {
                ForEach(0..<24, id: \.self) { value in
                    Text("\(value) hr")
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Minutes", selection: $minutes) {
                ForEach(0..<60, id: \.self) { value in
                    Text("\(value) min")
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

            Text("App will close when the timer ends")
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
                Text("Cancel")
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
                    Text("Start")
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
