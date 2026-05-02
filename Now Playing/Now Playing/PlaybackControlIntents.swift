//
//  PlaybackControlIntents.swift
//  Now Playing
//
//  Created by Gemini on 2/28/26.
//

import AppIntents
import WidgetKit

struct PlayPauseIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play/Pause"
    static var description = IntentDescription("Toggles playback.")

    func perform() async throws -> some IntentResult {
        if let controller = await PlaybackControlProvider.shared {
            let connected = await controller.connectIfNeeded()
            if connected {
                await MainActor.run {
                    if controller.isPaused {
                        controller.play()
                    } else {
                        controller.pause()
                    }
                }
            }
        }
        
        // Update shared state for immediate UI feedback in the widget
        let state = PlaybackStateManager.shared.load()
        var newState = state
        newState.isPaused.toggle()
        newState.lastUpdated = Date()
        PlaybackStateManager.shared.save(newState)

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SkipNextIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Skip Next"
    static var description = IntentDescription("Skips to the next track.")

    func perform() async throws -> some IntentResult {
        if let controller = await PlaybackControlProvider.shared {
            let connected = await controller.connectIfNeeded()
            if connected {
                await MainActor.run {
                    controller.skipToNext()
                }
            }
        }

        var state = PlaybackStateManager.shared.load()
        state.lastUpdated = Date()
        PlaybackStateManager.shared.save(state)

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SkipPreviousIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Skip Previous"
    static var description = IntentDescription("Skips to the previous track.")

    func perform() async throws -> some IntentResult {
        if let controller = await PlaybackControlProvider.shared {
            let connected = await controller.connectIfNeeded()
            if connected {
                controller.skipToPrevious()
            }
        }

        var state = PlaybackStateManager.shared.load()
        state.lastUpdated = Date()
        PlaybackStateManager.shared.save(state)

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
