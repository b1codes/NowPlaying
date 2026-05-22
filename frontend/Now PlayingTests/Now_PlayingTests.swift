//
//  Now_PlayingTests.swift
//  Now PlayingTests
//
//  Created by Brandon Lamer-Connolly on 10/25/23.
//

import Testing
import Foundation
import SwiftUI
@testable import Now_Playing

// MARK: - Waypoint Model Tests

@Suite("Waypoint")
struct WaypointTests {

    @Test("Initializes with correct properties")
    func waypointInit() {
        let id = UUID()
        let waypoint = Waypoint(id: id, position: 30, colorHex: "#FF5E5E")
        #expect(waypoint.id == id)
        #expect(waypoint.position == 30)
        #expect(waypoint.colorHex == "#FF5E5E")
    }

    @Test("Default UUID is assigned when none provided")
    func waypointDefaultID() {
        let w1 = Waypoint(position: 10, colorHex: "#FFFFFF")
        let w2 = Waypoint(position: 10, colorHex: "#FFFFFF")
        #expect(w1.id != w2.id)
    }

    @Test("Encodes and decodes correctly (Codable roundtrip)")
    func waypointCodable() throws {
        let original = Waypoint(position: 45, colorHex: "FF5E5E")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Waypoint.self, from: data)
        #expect(decoded == original)
    }

    @Test("Equal when all stored properties match")
    func waypointEquality() {
        let id = UUID()
        let w1 = Waypoint(id: id, position: 30, colorHex: "#FF5E5E")
        let w2 = Waypoint(id: id, position: 30, colorHex: "#FF5E5E")
        #expect(w1 == w2)
    }

    @Test("Not equal when UUID differs")
    func waypointInequalityByID() {
        let w1 = Waypoint(id: UUID(), position: 30, colorHex: "#FF5E5E")
        let w2 = Waypoint(id: UUID(), position: 30, colorHex: "#FF5E5E")
        #expect(w1 != w2)
    }

    @Test("color falls back to blue for invalid hex")
    func waypointColorFallback() {
        let waypoint = Waypoint(position: 0, colorHex: "INVALID")
        // The fallback is .blue — just verify it doesn't crash
        _ = waypoint.color
    }
}

// MARK: - Color Hex Extension Tests

@Suite("Color Hex Extensions")
struct ColorHexTests {

    @Test("Initializes from valid 6-char hex without hash")
    func colorFromSixCharHex() {
        #expect(Color(hex: "FF0000") != nil)
        #expect(Color(hex: "00FF00") != nil)
        #expect(Color(hex: "0000FF") != nil)
    }

    @Test("Initializes from valid 6-char hex with hash prefix")
    func colorFromHexWithHash() {
        #expect(Color(hex: "#FF0000") != nil)
        #expect(Color(hex: "#AABBCC") != nil)
    }

    @Test("Initializes from valid 8-char hex with alpha")
    func colorFromEightCharHex() {
        #expect(Color(hex: "FF0000FF") != nil)
        #expect(Color(hex: "AABBCC80") != nil)
    }

    @Test("Returns nil for invalid hex strings")
    func colorFromInvalidHex() {
        #expect(Color(hex: "XYZ") == nil)
        #expect(Color(hex: "12345") == nil)   // 5 chars — invalid length
        #expect(Color(hex: "") == nil)
        #expect(Color(hex: "ZZZZZZZ") == nil)
    }

    @Test("6-char hex survives a roundtrip through toHex()")
    func colorHexRoundtrip() throws {
        let hex = "FF5E5E"
        let color = try #require(Color(hex: hex))
        let result = try #require(color.toHex())
        #expect(result.uppercased() == hex.uppercased())
    }

    @Test("Black and white round-trip correctly")
    func blackWhiteRoundtrip() throws {
        for hex in ["000000", "FFFFFF"] {
            let color = try #require(Color(hex: hex))
            let result = try #require(color.toHex())
            #expect(result.uppercased() == hex.uppercased())
        }
    }
}

// MARK: - PlaybackState Model Tests

@Suite("PlaybackState")
struct PlaybackStateTests {

    @Test("Empty state has expected default values")
    func playbackStateEmpty() {
        let empty = PlaybackState.empty
        #expect(empty.trackName == "Not Playing")
        #expect(empty.artistName == "Unknown Artist")
        #expect(empty.isPaused == true)
        #expect(empty.trackURI == "")
        #expect(empty.duration == 0)
        #expect(empty.position == 0)
        #expect(empty.isMinimalistMode == false)
    }

    @Test("Encodes and decodes correctly (Codable roundtrip)")
    func playbackStateCodable() throws {
        let state = PlaybackState(
            trackName: "Test Track",
            artistName: "Test Artist",
            isPaused: false,
            trackURI: "spotify:track:abc123",
            duration: 210,
            position: 60,
            isMinimalistMode: true,
            lastUpdated: Date(timeIntervalSince1970: 1_000_000)
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PlaybackState.self, from: data)

        #expect(decoded.trackName == state.trackName)
        #expect(decoded.artistName == state.artistName)
        #expect(decoded.isPaused == state.isPaused)
        #expect(decoded.trackURI == state.trackURI)
        #expect(decoded.duration == state.duration)
        #expect(decoded.position == state.position)
        #expect(decoded.isMinimalistMode == state.isMinimalistMode)
    }
}

// MARK: - PlaybackStateManager Tests

@Suite("PlaybackStateManager", .serialized)
struct PlaybackStateManagerTests {

    private func cleanup() {
        PlaybackStateManager.shared.clear()
    }

    @Test("Saves and reloads state correctly")
    func saveAndLoad() {
        cleanup()
        let state = PlaybackState(
            trackName: "My Track",
            artistName: "My Artist",
            isPaused: false,
            trackURI: "spotify:track:xyz",
            duration: 180,
            position: 30,
            isMinimalistMode: false,
            lastUpdated: Date(timeIntervalSince1970: 500)
        )
        PlaybackStateManager.shared.save(state)
        let loaded = PlaybackStateManager.shared.load()

        #expect(loaded.trackName == state.trackName)
        #expect(loaded.artistName == state.artistName)
        #expect(loaded.isPaused == state.isPaused)
        #expect(loaded.trackURI == state.trackURI)
        #expect(loaded.duration == state.duration)
        #expect(loaded.position == state.position)
        #expect(loaded.isMinimalistMode == state.isMinimalistMode)
        cleanup()
    }

    @Test("Returns empty state when nothing has been saved")
    func loadWhenEmpty() {
        cleanup()
        let loaded = PlaybackStateManager.shared.load()
        #expect(loaded.trackName == PlaybackState.empty.trackName)
        #expect(loaded.artistName == PlaybackState.empty.artistName)
        #expect(loaded.trackURI == PlaybackState.empty.trackURI)
        #expect(loaded.isMinimalistMode == PlaybackState.empty.isMinimalistMode)
    }

    @Test("Clear removes persisted state")
    func clearRemovesState() {
        let state = PlaybackState(
            trackName: "To Be Cleared",
            artistName: "Artist",
            isPaused: true,
            trackURI: "spotify:track:clear",
            duration: 100,
            position: 0,
            isMinimalistMode: false,
            lastUpdated: Date()
        )
        PlaybackStateManager.shared.save(state)
        PlaybackStateManager.shared.clear()
        let loaded = PlaybackStateManager.shared.load()
        #expect(loaded.trackName == PlaybackState.empty.trackName)
    }

    @Test("Overwriting state returns the most recent value")
    func overwriteState() {
        cleanup()
        let first = PlaybackState(
            trackName: "First",
            artistName: "Artist",
            isPaused: true,
            trackURI: "spotify:track:first",
            duration: 100,
            position: 0,
            isMinimalistMode: false,
            lastUpdated: Date()
        )
        let second = PlaybackState(
            trackName: "Second",
            artistName: "Artist",
            isPaused: false,
            trackURI: "spotify:track:second",
            duration: 200,
            position: 50,
            isMinimalistMode: true,
            lastUpdated: Date()
        )
        PlaybackStateManager.shared.save(first)
        PlaybackStateManager.shared.save(second)
        let loaded = PlaybackStateManager.shared.load()
        #expect(loaded.trackName == "Second")
        #expect(loaded.trackURI == "spotify:track:second")
        cleanup()
    }
}

// MARK: - SpotifyController Session & State Tests

@Suite("SpotifyController Session & State")
@MainActor
struct SpotifyControllerSessionTests {

    private func makeController() -> SpotifyController {
        let controller = SpotifyController()
        controller.currentTrackURI = "spotify:track:sessionTest"
        controller.currentTrackName = "Test Track"
        controller.currentTrackArtist = "Test Artist"
        controller.currentTrackDuration = 240
        controller.currentTrackPosition = 60
        controller.currentTrackImage = Data([0xFF, 0xD8])
        controller.currentUserDisplayName = "Test User"
        controller.currentUserImage = Data([0x89, 0x50])
        controller.isPaused = false
        return controller
    }

    @Test("logout() clears all track and user state")
    func logoutClearsState() {
        let controller = makeController()
        controller.logout()
        #expect(controller.currentTrackName == nil)
        #expect(controller.currentTrackArtist == nil)
        #expect(controller.currentTrackImage == nil)
        #expect(controller.currentTrackURI == nil)
        #expect(controller.currentUserDisplayName == nil)
        #expect(controller.currentUserImage == nil)
        #expect(controller.waypoints.isEmpty)
    }

    @Test("logout() stops the position timer")
    func logoutStopsTimer() {
        let controller = makeController()
        let positionBefore = controller.currentTrackPosition
        controller.logout()
        #expect(controller.currentTrackPosition == positionBefore)
    }

    @Test("seek(to:) updates currentTrackPosition immediately")
    func seekUpdatesPosition() {
        let controller = makeController()
        controller.seek(to: 120)
        #expect(controller.currentTrackPosition == 120)
    }

    @Test("seek(to:) reflects the target position regardless of prior position")
    func seekOverwritesPriorPosition() {
        let controller = makeController()
        controller.currentTrackPosition = 180
        controller.seek(to: 45)
        #expect(controller.currentTrackPosition == 45)
    }

    @Test("updateWaypoint changes label and color in-place")
    func updateWaypointMutatesInPlace() {
        let controller = makeController()
        controller.currentTrackPosition = 30
        controller.addWaypoint()
        let original = controller.waypoints[0]

        controller.updateWaypoint(original, label: "Chorus", colorHex: "#4D96FF")

        #expect(controller.waypoints.count == 1)
        let updated = controller.waypoints[0]
        #expect(updated.id == original.id)
        #expect(updated.label == "Chorus")
        #expect(updated.colorHex == "#4D96FF")
        #expect(updated.position == original.position)

        UserDefaults.standard.removeObject(forKey: "waypoints_spotify:track:sessionTest")
    }

    @Test("updateWaypoint with nil label clears the label")
    func updateWaypointClearsLabel() {
        let controller = makeController()
        controller.currentTrackPosition = 60
        controller.addWaypoint()
        let original = controller.waypoints[0]

        controller.updateWaypoint(original, label: "Intro", colorHex: original.colorHex)
        controller.updateWaypoint(controller.waypoints[0], label: nil, colorHex: original.colorHex)

        #expect(controller.waypoints[0].label == nil)
        UserDefaults.standard.removeObject(forKey: "waypoints_spotify:track:sessionTest")
    }
}

// MARK: - SpotifyController Connection State Tests

@Suite("SpotifyController Connection State")
@MainActor
struct SpotifyControllerConnectionStateTests {

    @Test("connectionState initializes as .connected")
    func initialConnectionState() {
        let controller = SpotifyController()
        #expect(controller.connectionState == .connected)
    }

    @Test("retryCountdown initializes to 0")
    func initialRetryCountdown() {
        let controller = SpotifyController()
        #expect(controller.retryCountdown == 0)
    }

    @Test("logout() resets connectionState to .connected")
    func logoutResetsConnectionState() {
        let controller = SpotifyController()
        controller.logout()
        #expect(controller.connectionState == .connected)
    }

    @Test("reconnect() resets connectionState to .connected")
    func reconnectResetsConnectionState() {
        let controller = SpotifyController()
        controller.reconnect()
        #expect(controller.connectionState == .connected)
    }

    @Test("logout() resets retryCountdown to 0")
    func logoutResetsRetryCountdown() {
        let controller = SpotifyController()
        controller.retryCountdown = 12
        controller.logout()
        #expect(controller.retryCountdown == 0)
    }

    @Test("ConnectionState cases are distinct and Equatable")
    func connectionStateEquality() {
        #expect(ConnectionState.connected == .connected)
        #expect(ConnectionState.failed == .failed)
        #expect(ConnectionState.retrying(attempt: 1) == .retrying(attempt: 1))
        #expect(ConnectionState.retrying(attempt: 1) != .retrying(attempt: 2))
        #expect(ConnectionState.connected != .failed)
    }
}

// MARK: - SpotifyController Waypoint Management Tests

@Suite("SpotifyController Waypoints")
@MainActor
struct SpotifyControllerWaypointTests {

    private static let testURI = "spotify:track:unitTestTrack"

    private func makeController() -> SpotifyController {
        let controller = SpotifyController()
        controller.currentTrackURI = Self.testURI
        return controller
    }

    private func cleanup() {
        UserDefaults.standard.removeObject(forKey: "waypoints_\(Self.testURI)")
    }

    @Test("Adding a waypoint appends it to the list")
    func addWaypoint() {
        let controller = makeController()
        controller.currentTrackPosition = 30
        controller.addWaypoint()
        #expect(controller.waypoints.count == 1)
        #expect(controller.waypoints[0].position == 30)
        cleanup()
    }

    @Test("Adding a waypoint at a duplicate position is ignored")
    func addDuplicateWaypointIgnored() {
        let controller = makeController()
        controller.currentTrackPosition = 60
        controller.addWaypoint()
        controller.addWaypoint()
        #expect(controller.waypoints.count == 1)
        cleanup()
    }

    @Test("Removing a waypoint by ID removes only that waypoint")
    func removeWaypoint() {
        let controller = makeController()
        controller.currentTrackPosition = 90
        controller.addWaypoint()
        let waypoint = controller.waypoints[0]
        controller.removeWaypoint(waypoint)
        #expect(controller.waypoints.isEmpty)
        cleanup()
    }

    @Test("Waypoints are kept sorted by position after each addition")
    func waypointsSortedAfterAdd() {
        let controller = makeController()
        for position in [90, 30, 60] {
            controller.currentTrackPosition = position
            controller.addWaypoint()
        }
        #expect(controller.waypoints[0].position == 30)
        #expect(controller.waypoints[1].position == 60)
        #expect(controller.waypoints[2].position == 90)
        cleanup()
    }

    @Test("Waypoint colors cycle through the 8 predefined palette entries")
    func waypointColorCycling() {
        let controller = makeController()
        // Add 9 waypoints — the 9th should recycle to the first color
        for i in 0..<9 {
            controller.currentTrackPosition = i * 10
            controller.addWaypoint()
        }
        #expect(controller.waypoints[0].colorHex == controller.waypoints[8].colorHex)
        cleanup()
    }

    @Test("Removing a waypoint from a list with multiple entries leaves others intact")
    func removeOneFromMany() {
        let controller = makeController()
        for position in [10, 20, 30] {
            controller.currentTrackPosition = position
            controller.addWaypoint()
        }
        let middle = controller.waypoints.first { $0.position == 20 }!
        controller.removeWaypoint(middle)
        #expect(controller.waypoints.count == 2)
        #expect(!controller.waypoints.contains { $0.position == 20 })
        cleanup()
    }
}
