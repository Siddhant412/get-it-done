//
//  GetItDoneWidgetsLiveActivity.swift
//  GetItDoneWidgets
//
//  Created by Siddhant Raje on 1/23/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct GetItDoneWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct GetItDoneWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GetItDoneWidgetsAttributes.self) { context in
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

extension GetItDoneWidgetsAttributes {
    fileprivate static var preview: GetItDoneWidgetsAttributes {
        GetItDoneWidgetsAttributes(name: "World")
    }
}

extension GetItDoneWidgetsAttributes.ContentState {
    fileprivate static var smiley: GetItDoneWidgetsAttributes.ContentState {
        GetItDoneWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: GetItDoneWidgetsAttributes.ContentState {
         GetItDoneWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: GetItDoneWidgetsAttributes.preview) {
   GetItDoneWidgetsLiveActivity()
} contentStates: {
    GetItDoneWidgetsAttributes.ContentState.smiley
    GetItDoneWidgetsAttributes.ContentState.starEyes
}
