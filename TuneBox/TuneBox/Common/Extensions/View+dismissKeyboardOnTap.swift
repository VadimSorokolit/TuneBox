//
//  View+dismissKeyboardOnTap.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 25.06.2026.
//

import SwiftUI

extension View {

    func dismissKeyboardOnTap(
        focused: FocusState<Bool>.Binding
    ) -> some View {
        modifier(
            DismissKeyboardOnTapModifier(
                isFocused: focused
            )
        )
    }

}
