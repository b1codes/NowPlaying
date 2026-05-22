//
//  iOS_WidgetLiveActivity.swift
//  iOS Widget
//
//  Created by Brandon Lamer-Connolly on 8/30/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct IOSWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct IOSWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IOSWidgetAttributes.self) { context in
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

extension IOSWidgetAttributes {
    fileprivate static var preview: IOSWidgetAttributes {
        IOSWidgetAttributes(name: "World")
    }
}

extension IOSWidgetAttributes.ContentState {
    fileprivate static var smiley: IOSWidgetAttributes.ContentState {
        IOSWidgetAttributes.ContentState(emoji: "😀")
     }

     fileprivate static var starEyes: IOSWidgetAttributes.ContentState {
         IOSWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: IOSWidgetAttributes.preview) {
   IOSWidgetLiveActivity()
} contentStates: {
    IOSWidgetAttributes.ContentState.smiley
    IOSWidgetAttributes.ContentState.starEyes
}
