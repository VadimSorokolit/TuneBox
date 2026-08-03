//
//  TuneBoxWidgetLiveActivity.swift
//  TuneBoxWidget
//
//  Created by Nintendo on 03.08.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TuneBoxWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TuneBoxWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TuneBoxWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TuneBoxWidgetAttributes {
    
    fileprivate static var preview: TuneBoxWidgetAttributes {
        TuneBoxWidgetAttributes(name: "World")
    }
    
}

extension TuneBoxWidgetAttributes.ContentState {
    
    fileprivate static var smiley: TuneBoxWidgetAttributes.ContentState {
        TuneBoxWidgetAttributes.ContentState(emoji: "😀")
    }
    
    fileprivate static var starEyes: TuneBoxWidgetAttributes.ContentState {
        TuneBoxWidgetAttributes.ContentState(emoji: "🤩")
    }
    
}

#Preview("Notification", as: .content, using: TuneBoxWidgetAttributes.preview) {
   TuneBoxWidgetLiveActivity()
} contentStates: {
    TuneBoxWidgetAttributes.ContentState.smiley
    TuneBoxWidgetAttributes.ContentState.starEyes
}
