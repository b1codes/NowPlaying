//
//  PlaybackState.swift
//  Now Playing
//
//  Created by Gemini on 2/28/26.
//

import Foundation
import SwiftUI

@MainActor
protocol PlaybackControlling {
    func play()
    func pause()
    func skipToNext()
    func skipToPrevious()
    var isPaused: Bool { get }
    func connectIfNeeded() async -> Bool
}

class PlaybackControlProvider {
    static var shared: PlaybackControlling?
}

struct PlaybackState: Codable {
    var trackName: String
    var artistName: String
    var isPaused: Bool
    var trackURI: String
    var duration: Int
    var position: Int
    var isMinimalistMode: Bool
    var lastUpdated: Date

    /// Canonical "not connected" sentinel used throughout the app and widget as a safe fallback.
    static let empty = PlaybackState(
        trackName: "Not Playing",
        artistName: "Unknown Artist",
        isPaused: true,
        trackURI: "",
        duration: 0,
        position: 0,
        isMinimalistMode: false,
        lastUpdated: Date()
    )
}

/// Singleton that persists playback state and album art to the shared App Group container so the widget extension can read them.
class PlaybackStateManager {
    /// Shared instance used by both the app and widget targets.
    static let shared = PlaybackStateManager()

    // In a real app, you'd use an App Group ID here
    private let suiteName = "group.com.brandonlamer-connolly.nowplaying"
    private let storageKey = "playbackState"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Persists `state` to both the App Group shared defaults and `UserDefaults.standard`.
    func save(_ state: PlaybackState) {
        if let encoded = try? JSONEncoder().encode(state) {
            sharedDefaults?.set(encoded, forKey: storageKey)
            // Also save to standard for local use if needed
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    /// Loads the most recently saved state, preferring the App Group store. Returns `.empty` if nothing has been saved.
    func load() -> PlaybackState {
        let data = sharedDefaults?.data(forKey: storageKey) ?? UserDefaults.standard.data(forKey: storageKey)
        if let data = data, let decoded = try? JSONDecoder().decode(PlaybackState.self, from: data) {
            return decoded
        }
        return .empty
    }

    /// Removes persisted state from both stores and deletes the album art file from the App Group container and caches directory.
    func clear() {
        sharedDefaults?.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: storageKey)

        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("currentTrackImage.jpg")

        let fallbackURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("currentTrackImage.jpg")

        if let url = url { try? FileManager.default.removeItem(at: url) }
        if let fallbackURL = fallbackURL { try? FileManager.default.removeItem(at: fallbackURL) }
    }

    /// Writes JPEG image data to the App Group shared container (falls back to the caches directory).
    func saveImage(_ imageData: Data?) {
        guard let data = imageData else { return }
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("currentTrackImage.jpg")

        // Fallback to caches if App Group is not available
        let fallbackURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("currentTrackImage.jpg")

        try? data.write(to: url ?? fallbackURL!)
    }

    /// Reads the album art from the App Group container (or caches fallback). Returns `nil` if no image has been saved.
    func loadImage() -> UIImage? {
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("currentTrackImage.jpg")

        let fallbackURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("currentTrackImage.jpg")

        if let data = try? Data(contentsOf: url ?? fallbackURL!) {
            return UIImage(data: data)
        }
        return nil
    }
}
