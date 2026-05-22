//
//  SpotifyController.swift
//  Now Playing
//
//  Created by Brandon Lamer-Connolly on 7/19/24.
//

import AVFoundation
import Combine
import os
import SpotifyiOS
import SwiftUI
import WidgetKit

enum ConnectionState: Equatable {
    case connected
    case retrying(attempt: Int)
    case failed
}

@MainActor
final class SpotifyController: NSObject, ObservableObject, PlaybackControlling {
    static let shared = SpotifyController()
    
    let spotifyClientID =
        Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_API_CLIENT_ID")
        as? String
    let spotifyRedirectURL = URL(
        string: "spotify-ios-quick-start://spotify-login-callback"
    )!

    var accessToken: String?

    /// Spotify URI of the currently playing track (e.g. `spotify:track:abc123`).
    @Published var currentTrackURI: String?
    /// Display name of the current track.
    @Published var currentTrackName: String?
    /// Display name of the current track's primary artist.
    @Published var currentTrackArtist: String?
    /// Duration of the current track in seconds.
    @Published var currentTrackDuration: Int?
    /// JPEG data of the 300×300 album art for the current track.
    @Published var currentTrackImage: Data?
    /// Display name fetched from the Spotify `/v1/me` user profile endpoint.
    @Published var currentUserDisplayName: String?
    /// Profile photo data fetched from the Spotify user profile.
    @Published var currentUserImage: Data?
    /// Whether Spotify playback is currently paused. Changes persist state to the shared App Group.
    @Published var isPaused: Bool = true {
        didSet { saveState() }
    }

    /// Whether the minimalist UI mode is active.
    @AppStorage("isMinimalistMode") var isMinimalistMode: Bool = false {
        willSet { objectWillChange.send() }
        didSet { saveState() }
    }

    /// Current playback position in seconds, updated by a 1-second timer while playing.
    @Published var currentTrackPosition: Int = 0
    /// Number of seconds to skip forward or backward via `skipForward()` / `skipBackward()`.
    @Published var skipInterval: Int = 15
    /// Color-coded bookmarks for the current track, sorted ascending by position. Persisted per track URI.
    @Published var waypoints: [Waypoint] = []
    /// Whether Spotify shuffle is active.
    @Published var isShuffling: Bool = false
    /// Current repeat mode: `0` = off, `1` = track, `2` = context.
    @Published var repeatMode: UInt = 0
    /// Current SDK connection state; drives the disconnected banner in ContentView.
    @Published var connectionState: ConnectionState = .connected {
        didSet {
            handleConnectionStateChange()
        }
    }
    /// Whether the disconnected banner should be visible in the UI. Debounced by 3 seconds.
    @Published var showDisconnectBanner: Bool = false
    /// Countdown in seconds until the next automatic reconnect attempt.
    @Published var retryCountdown: Int = 0
    @Published var loopStart: Int?
    @Published var loopEnd: Int?
    @Published var currentVolume: Float = AVAudioSession.sharedInstance().outputVolume
    
    private var volumeObservation: NSKeyValueObservation?
    private var timer: Timer?
    private var bannerTask: Task<Void, Never>?

    private func handleConnectionStateChange() {
        if connectionState == .connected {
            bannerTask?.cancel()
            bannerTask = nil
            showDisconnectBanner = false
        } else {
            // Debounce the disconnected banner by 3 seconds
            // This prevents it from flashing during pauses or brief connection handovers
            guard bannerTask == nil else { return }
            bannerTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                showDisconnectBanner = true
            }
        }
    }

    private let logger = Logger(subsystem: "com.brandonlamer-connolly.nowplaying", category: "SpotifyConnection")
    private var retryAttempt = 0
    private let maxRetries = 5
    private let backoffDelays = [2, 4, 8, 16, 30]
    private var retryTask: Task<Void, Never>?
    private var isIntentionalDisconnect = false
    private var connectionContinuation: CheckedContinuation<Bool, Never>?

    /// Attempts to connect if not already connected, awaiting the result.
    func connectIfNeeded() async -> Bool {
        if appRemote.isConnected { return true }
        
        // Prevent multiple simultaneous connection attempts from blocking forever
        if connectionContinuation != nil {
            return false
        }
        
        return await withCheckedContinuation { continuation in
            self.connectionContinuation = continuation
            self.connect()
        }
    }

    private var connectCancellable: AnyCancellable?

    // Predefined colors for waypoints
    private let waypointColors = [
        "#FF5E5E", "#FFBB5C", "#FFD93D", "#6BCB77", "#4D96FF", "#B983FF", "#FF869E", "#54BAB9"
    ]

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Adds a waypoint at the current playback position. Silently ignores duplicates at the same second.
    func addWaypoint() {
        let position = currentTrackPosition
        // Prevent duplicate waypoints at same second
        guard !waypoints.contains(where: { $0.position == position }) else { return }
        haptic(.medium)

        let colorHex = waypointColors[waypoints.count % waypointColors.count]
        let newWaypoint = Waypoint(position: position, colorHex: colorHex)
        waypoints.append(newWaypoint)
        waypoints.sort { $0.position < $1.position }
        print("Waypoint added: \(newWaypoint.position)s. Total waypoints: \(waypoints.count)")
        saveWaypoints()
    }

    /// Seeks to `seconds` in the current track. Updates `currentTrackPosition` immediately before the SDK call resolves.
    func seek(to seconds: Int) {
        self.currentTrackPosition = seconds
        appRemote.playerAPI?.seek(toPosition: seconds * 1000, callback: { (_, error) in
            if let error = error {
                print("Error seeking: \(error.localizedDescription)")
            }
        })
    }

    /// Seeks to the position of `waypoint` and fires a medium haptic.
    func seekToWaypoint(_ waypoint: Waypoint) {
        haptic(.medium)
        seek(to: waypoint.position)
    }

    /// Removes `waypoint` by ID and persists the updated list.
    func removeWaypoint(_ waypoint: Waypoint) {
        haptic(.heavy)
        waypoints.removeAll { $0.id == waypoint.id }
        saveWaypoints()
    }

    /// Updates the label and color of an existing waypoint in-place, then persists.
    func updateWaypoint(_ waypoint: Waypoint, label: String?, colorHex: String) {
        guard let index = waypoints.firstIndex(where: { $0.id == waypoint.id }) else { return }
        waypoints[index] = Waypoint(id: waypoint.id, position: waypoint.position, colorHex: colorHex, label: label)
        saveWaypoints()
    }

    func setLoopIn() {
        haptic(.medium)
        loopStart = currentTrackPosition
    }

    func setLoopOut() {
        haptic(.medium)
        // Ensure out is after in
        if let start = loopStart, currentTrackPosition > start {
            loopEnd = currentTrackPosition
        } else {
            // If they try to set Out before In, just set In instead.
            loopStart = currentTrackPosition
            loopEnd = nil
        }
    }

    func clearLoop() {
        haptic(.light)
        loopStart = nil
        loopEnd = nil
    }

    private func saveWaypoints() {
        guard let trackURI = currentTrackURI else { return }
        if let encoded = try? JSONEncoder().encode(waypoints) {
            UserDefaults.standard.set(encoded, forKey: "waypoints_\(trackURI)")
        }
        saveState()
    }

    private func loadWaypoints(for trackURI: String) {
        if let data = UserDefaults.standard.data(forKey: "waypoints_\(trackURI)"),
           let decoded = try? JSONDecoder().decode([Waypoint].self, from: data) {
            self.waypoints = decoded
        } else {
            self.waypoints = []
        }
    }

    private var disconnectCancellable: AnyCancellable?

    private func saveState() {
        let state = PlaybackState(
            trackName: currentTrackName ?? "Not Playing",
            artistName: currentTrackArtist ?? "Unknown Artist",
            isPaused: isPaused,
            trackURI: currentTrackURI ?? "",
            duration: currentTrackDuration ?? 0,
            position: currentTrackPosition,
            isMinimalistMode: isMinimalistMode,
            lastUpdated: Date()
        )
        PlaybackStateManager.shared.save(state)
        PlaybackStateManager.shared.saveImage(currentTrackImage)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Extracts the OAuth access token from the Spotify callback URL and triggers user profile fetch.
    func setAccessToken(from url: URL) {
        let parameters = appRemote.authorizationParameters(from: url)

        if let accessToken = parameters?[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = accessToken
            self.accessToken = accessToken
            fetchUserProfile()
        } else if (parameters?[SPTAppRemoteErrorDescriptionKey]) != nil {
            // Handle the error
        }
    }

    /// Opens the Spotify app to begin the OAuth authorization flow.
    func authorize() {
        self.appRemote.authorizeAndPlayURI("")
    }

    lazy var configuration = SPTConfiguration(
        clientID: spotifyClientID!,
        redirectURL: spotifyRedirectURL
    )

    lazy var appRemote: SPTAppRemote = {
        let appRemote = SPTAppRemote(
            configuration: configuration,
            logLevel: .debug
        )
        appRemote.connectionParameters.accessToken = self.accessToken
        appRemote.delegate = self
        return appRemote
    }()

    /// Connects to the Spotify app remote. Requires `accessToken` to be set on `connectionParameters`. Cancels any pending retry.
    func connect() {
        retryTask?.cancel()
        retryTask = nil
        guard appRemote.connectionParameters.accessToken != nil else { return }
        appRemote.connect()
    }

    /// Manually retries the SDK connection after a failure, resetting the backoff counter.
    func reconnect() {
        retryAttempt = 0
        connectionState = .connected
        connect()
    }

    /// Disconnects from the Spotify app remote. No-ops if not currently connected.
    func disconnect() {
        guard appRemote.isConnected else { return }
        isIntentionalDisconnect = true
        appRemote.disconnect()
    }

    /// Fully resets auth and playback state: disconnects, clears all published properties, stops the timer, and wipes the shared App Group.
    func logout() {
        retryTask?.cancel()
        retryTask = nil
        retryAttempt = 0
        retryCountdown = 0
        connectionState = .connected
        disconnect()
        self.accessToken = nil
        self.currentTrackName = nil
        self.currentTrackArtist = nil
        self.currentTrackImage = nil
        self.currentUserDisplayName = nil
        self.currentUserImage = nil
        self.currentTrackURI = nil
        self.waypoints = []
        self.appRemote.connectionParameters.accessToken = nil
        stopTimer()
        PlaybackStateManager.shared.clear()
        saveState()
    }

    private func fetchUserProfile() {
        guard let accessToken = self.accessToken else { return }

        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                   if let displayName = json["display_name"] as? String {
                        DispatchQueue.main.async {
                            self.currentUserDisplayName = displayName
                        }
                    }

                    if let images = json["images"] as? [[String: Any]],
                       let firstImage = images.first,
                       let imageUrl = firstImage["url"] as? String {
                        Task { @MainActor in
                            self.fetchUserImage(from: imageUrl)
                        }
                    }
                }
            } catch {
                print("Error decoding user profile: \(error)")
            }
        }.resume()
    }

    private func fetchUserImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                self.currentUserImage = data
            }
        }.resume()
    }

    override init() {
        super.init()
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
        
        volumeObservation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.initial, .new]) { [weak self] session, change in
            guard let newVolume = change.newValue else { return }
            Task { @MainActor in
                self?.currentVolume = newVolume
            }
        }
        
        connectCancellable = NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { _ in
            self.connect()
        }

        disconnectCancellable = NotificationCenter.default.publisher(
            for: UIApplication.willResignActiveNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { _ in
            self.disconnect()
        }
    }

    /// Fetches a 300×300 album art image for the current track via the Spotify image API and stores JPEG data in `currentTrackImage`.
    func fetchImage() {
        appRemote.playerAPI?.getPlayerState { (result, error) in
            if let error = error {
                print("Error getting player state: \(error)")
            } else if let playerState = result as? SPTAppRemotePlayerState {
                self.appRemote.imageAPI?.fetchImage(
                    forItem: playerState.track,
                    with: CGSize(width: 300, height: 300),
                    callback: { (image, error) in
                        if let error = error {
                            print(
                                "Error fetching track image: \(error.localizedDescription)"
                            )
                        } else if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                self.currentTrackImage = image.jpegData(compressionQuality: 1.0)
                            }
                        }
                    }
                )
            }
        }
    }

    /// Skips to the previous track.
    func skipToPrevious() {
        haptic(.medium)
        appRemote.playerAPI?.skip(toPrevious: { _, error in
            if let error = error {
                print(
                    "Error skipping to previous: \(error.localizedDescription)"
                )
            }
        })
    }

    /// Resumes Spotify playback.
    func play() {
        haptic(.heavy)
        isPaused = false
        startTimer()
        appRemote.playerAPI?.resume({ _, error in
            if let error = error {
                print("Error playing: \(error.localizedDescription)")
            }
        })
    }

    /// Pauses Spotify playback.
    func pause() {
        haptic(.heavy)
        isPaused = true
        stopTimer()
        appRemote.playerAPI?.pause({ _, error in
            if let error = error {
                print("Error pausing: \(error.localizedDescription)")
            }
        })
    }

    /// Skips to the next track.
    func skipToNext() {
        haptic(.medium)
        appRemote.playerAPI?.skip(toNext: { _, error in
            if let error = error {
                print("Error skipping to next: \(error.localizedDescription)")
            }
        })
    }

    /// Seeks backward by `skipInterval` seconds, fetching the live position from the SDK first.
    func skipBackward() {
        haptic(.light)
        appRemote.playerAPI?.getPlayerState { [weak self] (result, error) in
            guard let self = self else { return }
            if let error = error {
                print(
                    "Error getting player state: \(error.localizedDescription)"
                )
            } else if let playerState = result as? SPTAppRemotePlayerState {
                let currentPosition = playerState.playbackPosition
                let newPosition = max(0, currentPosition - (self.skipInterval * 1000))
                
                Task { @MainActor in
                    self.currentTrackPosition = Int(newPosition) / 1000
                }

                self.appRemote.playerAPI?.seek(
                    toPosition: newPosition,
                    callback: { (_, error) in
                        if let error = error {
                            print(
                                "Error seeking backward: \(error.localizedDescription)"
                            )
                        }
                    }
                )
            }
        }
    }

    /// Seeks forward by `skipInterval` seconds, fetching the live position from the SDK first.
    func skipForward() {
        haptic(.light)
        appRemote.playerAPI?.getPlayerState { [weak self] (result, error) in
            guard let self = self else { return }
            if let error = error {
                print(
                    "Error getting player state: \(error.localizedDescription)"
                )
            } else if let playerState = result as? SPTAppRemotePlayerState {
                let currentPosition = playerState.playbackPosition
                let newPosition = currentPosition + (self.skipInterval * 1000)
                
                Task { @MainActor in
                    self.currentTrackPosition = Int(newPosition) / 1000
                }

                self.appRemote.playerAPI?.seek(
                    toPosition: newPosition,
                    callback: { (_, error) in
                        if let error = error {
                            print(
                                "Error seeking forward: \(error.localizedDescription)"
                            )
                        }
                    }
                )
            }
        }
    }

    /// Toggles Spotify shuffle on or off.
    func toggleShuffle() {
        haptic(.light)
        appRemote.playerAPI?.setShuffle(!isShuffling, callback: { _, error in
            if let error = error {
                print("Error setting shuffle: \(error.localizedDescription)")
            }
        })
    }

    /// Cycles the repeat mode: off → track → context → off.
    func toggleRepeat() {
        haptic(.light)
        appRemote.playerAPI?.getPlayerState { (result, error) in
            if let playerState = result as? SPTAppRemotePlayerState {
                let currentMode = playerState.playbackOptions.repeatMode
                var nextMode = currentMode

                // Cycle: off (0) -> track (1) -> context (2) -> off (0)
                if currentMode.rawValue == 0 {
                    nextMode = .track
                } else if currentMode.rawValue == 1 {
                    nextMode = .context
                } else {
                    nextMode = .off
                }

                self.appRemote.playerAPI?.setRepeatMode(nextMode, callback: { _, error in
                    if let error = error {
                        print("Error setting repeat mode: \(error.localizedDescription)")
                    }
                })
            }
        }
    }

    // [NEW] Timer Methods
    private func startTimer() {
        stopTimer()  // Prevent duplicate timers
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Fuzzy A-B Looping Check
                if let end = self.loopEnd, let start = self.loopStart, self.currentTrackPosition >= end {
                    self.seek(to: start)
                    return // skip incrementing since we just seeked
                }
                
                if self.currentTrackPosition
                    < (self.currentTrackDuration ?? Int.max) {
                    self.currentTrackPosition += 1
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleRetry() {
        guard retryAttempt < maxRetries else {
            connectionState = .failed
            retryCountdown = 0
            logger.warning("Max retries (\(self.maxRetries)) exhausted. Giving up.")
            return
        }
        let delay = backoffDelays[retryAttempt]
        retryAttempt += 1
        connectionState = .retrying(attempt: retryAttempt)

        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var remaining = delay
            while remaining > 0 {
                guard !Task.isCancelled else { return }
                self.retryCountdown = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remaining -= 1
            }
            guard !Task.isCancelled else { return }
            self.logger.debug("Retrying connection (attempt \(self.retryAttempt)/\(self.maxRetries))...")
            self.connect()
        }
    }
}

extension SpotifyController: @preconcurrency SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        retryTask?.cancel()
        retryTask = nil
        retryAttempt = 0
        connectionState = .connected
        logger.info("Connection established.")
        self.appRemote = appRemote
        self.appRemote.playerAPI?.delegate = self
        self.appRemote.playerAPI?.subscribe(toPlayerState: { (_, error) in
            if let error = error {
                print("Error subscribing to player state: \(error.localizedDescription)")
            } else {
                print("Successfully subscribed to player state")
            }
        })
        
        connectionContinuation?.resume(returning: true)
        connectionContinuation = nil
    }

    func appRemote(
        _ appRemote: SPTAppRemote,
        didFailConnectionAttemptWithError error: Error?
    ) {
        if let error = error {
            logger.error("Connection attempt failed: \(error.localizedDescription)")
        } else {
            logger.debug("Connection attempt failed (no error description).")
        }
        
        connectionContinuation?.resume(returning: false)
        connectionContinuation = nil
        
        guard accessToken != nil else { return }
        scheduleRetry()
    }

    func appRemote(
        _ appRemote: SPTAppRemote,
        didDisconnectWithError error: Error?
    ) {
        defer { isIntentionalDisconnect = false }
        if let error = error {
            logger.error("Disconnected with error: \(error.localizedDescription)")
        } else {
            logger.debug("Disconnected cleanly.")
        }
        
        connectionContinuation?.resume(returning: false)
        connectionContinuation = nil
        
        guard !isIntentionalDisconnect else { return }
        scheduleRetry()
    }
}

extension SpotifyController: @preconcurrency SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        Task { @MainActor in
            let oldURI = self.currentTrackURI
            self.currentTrackURI = playerState.track.uri

            if oldURI != self.currentTrackURI, let newURI = self.currentTrackURI {
                loadWaypoints(for: newURI)
            }

            self.currentTrackName = playerState.track.name
            self.currentTrackArtist = playerState.track.artist.name
            self.currentTrackDuration = Int(playerState.track.duration) / 1000
            self.isPaused = playerState.isPaused
            self.isShuffling = playerState.playbackOptions.isShuffling
            self.repeatMode = playerState.playbackOptions.repeatMode.rawValue

            // [NEW] Update position and manage timer
            self.currentTrackPosition = Int(playerState.playbackPosition) / 1000

            if self.isPaused {
                stopTimer()
            } else {
                startTimer()
            }

            fetchImage()
            saveState()
        }
    }
}
