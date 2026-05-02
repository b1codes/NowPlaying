# Minimalist Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a simplified "Minimalist Mode" UI for driving, featuring oversized controls and a seamless morphing transition from the standard view.

**Architecture:** Use a state-driven approach with `isMinimalistMode` in `SpotifyController`. Implement `MinimalistView.swift` as a separate component and use `matchedGeometryEffect` in `ContentView` to animate shared elements (Play/Pause, Skip, Waypoint Dock) between layouts.

**Tech Stack:** SwiftUI, AppIntents, Spotify iOS SDK.

---

### Task 1: Update State & Controller logic

**Files:**
- Modify: `Now Playing/Now Playing/SpotifyController.swift`
- Modify: `Now Playing/Now Playing/PlaybackState.swift`

- [ ] **Step 1: Add `isMinimalistMode` to `SpotifyController`**

```swift
// Around line 70
@AppStorage("isMinimalistMode") var isMinimalistMode: Bool = false {
    didSet { saveState() }
}
```

- [ ] **Step 2: Update `PlaybackState` to include minimalist state**

```swift
// In PlaybackState.swift
struct PlaybackState: Codable {
    // ... existing fields
    let isMinimalistMode: Bool
}
```

- [ ] **Step 3: Update `saveState()` in `SpotifyController`**

```swift
// In SpotifyController.swift
private func saveState() {
    let state = PlaybackState(
        // ... existing fields
        isMinimalistMode: isMinimalistMode,
        lastUpdated: Date()
    )
    // ... rest of save logic
}
```

- [ ] **Step 4: Commit**

```bash
git add "Now Playing/Now Playing/SpotifyController.swift" "Now Playing/Now Playing/PlaybackState.swift"
git commit -m "feat: add isMinimalistMode state and persistence"
```

---

### Task 2: Create MinimalistView Component

**Files:**
- Create: `Now Playing/Now Playing/MinimalistView.swift`

- [ ] **Step 1: Implement basic oversized layout**

```swift
import SwiftUI

struct MinimalistView: View {
    @EnvironmentObject var spotifyController: SpotifyController
    var namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Maximized Controls
            HStack(spacing: 60) {
                Button(action: { spotifyController.skipToPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .matchedGeometryEffect(id: "skipBack", in: namespace)

                Button(action: {
                    spotifyController.isPaused ? spotifyController.play() : spotifyController.pause()
                }) {
                    Image(systemName: spotifyController.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .matchedGeometryEffect(id: "playPause", in: namespace)

                Button(action: { spotifyController.skipToNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .matchedGeometryEffect(id: "skipForward", in: namespace)
            }
            .padding(.vertical, 100)
            .glassBackground()

            // Large Waypoint Dock
            MinimalistWaypointDock(namespace: namespace)
                .padding(.bottom, 50)

            Spacer()
        }
    }
}

struct MinimalistWaypointDock: View {
    @EnvironmentObject var spotifyController: SpotifyController
    var namespace: Namespace.ID

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 30) {
                ForEach(spotifyController.waypoints) { waypoint in
                    Button(action: { spotifyController.seekToWaypoint(waypoint) }) {
                        Circle()
                            .fill(waypoint.color)
                            .frame(width: 40, height: 40)
                            .shadow(radius: 4)
                    }
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(height: 100)
        .glassBackground()
        .matchedGeometryEffect(id: "waypointDock", in: namespace)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "Now Playing/Now Playing/MinimalistView.swift"
git commit -m "feat: implement MinimalistView with oversized controls"
```

---

### Task 3: Integrate Transition in ContentView

**Files:**
- Modify: `Now Playing/Now Playing/ContentView.swift`

- [ ] **Step 1: Add Namespace and state handling**

```swift
// In ContentView
@Namespace private var minimalistNamespace
// ...
```

- [ ] **Step 2: Refactor body to switch views**

```swift
// Replace the main VStack inside the ZStack
if spotifyController.isMinimalistMode {
    MinimalistView(namespace: minimalistNamespace)
        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
} else {
    // Current standard/DJ VStack logic
    // Add matchedGeometryEffect to relevant buttons:
    // .matchedGeometryEffect(id: "playPause", in: minimalistNamespace)
    // .matchedGeometryEffect(id: "skipBack", in: minimalistNamespace)
    // .matchedGeometryEffect(id: "skipForward", in: minimalistNamespace)
    // .matchedGeometryEffect(id: "waypointDock", in: minimalistNamespace)
}
```

- [ ] **Step 3: Add Toggle to Settings**

```swift
// In SettingsButton
Toggle("Minimalist (Driving) Mode", isOn: $spotifyController.isMinimalistMode)
```

- [ ] **Step 4: Commit**

```bash
git add "Now Playing/Now Playing/ContentView.swift"
git commit -m "feat: integrate MinimalistView transition in ContentView"
```

---

### Task 4: Implement AppIntent for Focus Integration

**Files:**
- Create: `Now Playing/Now Playing/MinimalistIntent.swift`

- [ ] **Step 1: Define ToggleMinimalistMode intent**

```swift
import AppIntents

struct ToggleMinimalistMode: AppIntent {
    static var title: LocalizedStringResource = "Toggle Minimalist Mode"
    static var description = IntentDescription("Enables or disables the driving-friendly interface.")

    @Parameter(title: "Enabled")
    var enabled: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        SpotifyController.shared.isMinimalistMode = enabled
        return .result()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "Now Playing/Now Playing/MinimalistIntent.swift"
git commit -m "feat: add AppIntent for Minimalist Mode toggle"
```

---

### Task 5: Final Verification

- [ ] **Step 1: Test manual toggle**
- [ ] **Step 2: Verify transition animation**
- [ ] **Step 3: Test AppIntent via Shortcuts app**
