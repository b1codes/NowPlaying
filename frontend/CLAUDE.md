# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This App Does

**Now Playing** is a Spotify control and metadata display app for iOS/watchOS. Core features:
- Display current track info (name, artist, album art)
- Playback controls (play/pause, skip, shuffle, repeat, seek)
- **Waypoints** — color-coded bookmarks at specific positions within a track
- Custom skip intervals (5s, 10s, 15s, 30s)
- Theme customization (Light, Dark, Album Art with blur)
- iOS Home Screen / Lock Screen widgets
- App Intents for Siri integration

## Build & Test

Build and run exclusively through **Xcode** — no Makefile or build scripts exist. Open `Now Playing.xcodeproj`.

To run tests: `Cmd+U` in Xcode, or via CLI:
```bash
xcodebuild test -project "Now Playing.xcodeproj" -scheme "Now Playing" -destination "platform=iOS Simulator,name=iPhone 16"
```

The test suite (`Now PlayingTests/`, `Now PlayingUITests/`) is minimal templates with little real coverage.

## Architecture

**MVVM-lite** with SwiftUI + Combine.

### State Flow

```
NowPlayingApp (@main)
  └── @StateObject SpotifyController  ← single source of truth
        ↓ injected as @EnvironmentObject
      ContentView
        ├── BackgroundLayer
        ├── MainControls
        ├── ProgressBarLayer  (slider + waypoint markers)
        ├── WaypointDock      (scrollable bookmark list)
        ├── AccountMenu
        └── SettingsButton
```

### Key Files

| File | Role |
|------|------|
| `Now Playing/SpotifyController.swift` | Core ViewModel; all Spotify SDK integration, playback commands, timer, waypoints persistence |
| `Now Playing/ContentView.swift` | Root view; subviews are modular components within this file |
| `Now Playing/PlaybackState.swift` | `PlaybackState` (Codable model) + `PlaybackStateManager` singleton (App Group sharing with widget) |
| `Now Playing/Waypoint.swift` | `Waypoint` model (UUID, position in seconds, hex color) + `Color` hex extensions |
| `Now Playing/Now_PlayingApp.swift` | App entry; routes between `AuthorizationView` and `ContentView` |
| `iOS Widget/iOS_Widget.swift` | Home screen/lock screen widget; reads shared state via `PlaybackStateManager` |

### SpotifyController

`SpotifyController` is an `NSObject` + `ObservableObject` that:
- Owns `SPTAppRemote` (lazy-loaded, Spotify iOS SDK)
- Conforms to `SPTAppRemoteDelegate` and `SPTAppRemotePlayerStateDelegate`
- Publishes all track metadata, playback state, and waypoints
- Manages a `Timer` for position tracking while playing
- Persists waypoints per-track URI in `UserDefaults`
- Writes playback state + album art to the shared App Group container for widget access

### Data Persistence Layers

| Layer | Used For |
|-------|----------|
| `UserDefaults` (standard) | App preferences (theme, blur radius, skip interval), waypoints |
| `UserDefaults` (App Group: `group.com.brandonlamer-connolly.nowplaying`) | Shared playback state with widget extension |
| `FileManager` (shared container) | Album art image caching for widget |

### Spotify SDK Integration

- The Spotify iOS SDK (`SpotifyiOS` framework) is an Objective-C framework bridged via `Now Playing/Now-Playing-Bridging-Header.h`
- Spotify Client ID lives in `Config.xcconfig` (not committed — a `Sample.xcconfig` template exists)
- OAuth callback URL scheme: `spotify-ios-quick-start://spotify-login-callback` (registered in `Now-Playing-Info.plist`)
- Connection lifecycle: `authorize()` → app opens Spotify → callback → `setAccessToken()` → `connect()`

### Widget Architecture

The `iOS Widget` extension shares the `PlaybackState` model and `PlaybackControlIntents` with the main app. State flows one-way: main app writes to App Group → widget reads on timeline refresh. Widget playback control buttons use `AppIntent` actions.

### watchOS

Both `Watch App Watch App/` and `watchOS Watch App/` targets are template stubs (Hello World). Not production-ready.
