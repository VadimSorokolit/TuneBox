//
//  TuneBoxWidgetBundle.swift
//  TuneBoxWidget
//
//  Created by Vadim Sorokolit on 03.08.2026.
//

import WidgetKit
import SwiftUI

@main
struct TuneBoxWidgetBundle: WidgetBundle {
    var body: some Widget {
        TuneBoxWidget()
        TuneBoxWidgetControl()
        TuneBoxWidgetLiveActivity()
    }
}
