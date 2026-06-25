//
//  DismissKeyboardOnTapModifier.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.06.2026.
//

import SwiftUI

struct DismissKeyboardOnTapModifier: ViewModifier {
    @FocusState.Binding var isFocused: Bool

    func body(content: Content) -> some View {
        content.onTapGesture {
            isFocused = false
        }
    }
}
