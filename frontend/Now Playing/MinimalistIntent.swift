//
//  MinimalistIntent.swift
//  Now Playing
//
//  Created by Gemini on 2/28/26.
//

import AppIntents
import WidgetKit

struct ToggleMinimalistMode: AppIntent {
    static var title: LocalizedStringResource = "Toggle Minimalist Mode"
    static var description = IntentDescription("Enables or disables the driving-friendly interface.")

    @Parameter(title: "Enabled")
    var enabled: Bool

    init() {
        self.enabled = false
    }

    init(enabled: Bool) {
        self.enabled = enabled
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        SpotifyController.shared.isMinimalistMode = enabled
        return .result()
    }
}

struct MinimalistFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Minimalist Mode"
    static var description = IntentDescription("Automatically turn on Minimalist Mode during this Focus.")

    @Parameter(title: "Enabled", default: true)
    var enabled: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Minimalist Mode",
            subtitle: enabled ? "On" : "Off"
        )
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        SpotifyController.shared.isMinimalistMode = enabled
        return .result()
    }
}
