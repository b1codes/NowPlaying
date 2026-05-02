# Design Spec: Minimalist Mode (Task 86b9qgbng)

## Status: APPROVED

## 1. Overview
Implement a high-visibility, simplified interface for hands-occupied scenarios (Driving). The interface focuses on oversized touch targets and a seamless "morphing" transition from the standard `ContentView`.

## 2. Architecture & Components

### View Layer
- **`MinimalistView.swift`**: A new SwiftUI view containing the simplified driving layout.
- **`ContentView.swift`**: Updated to handle the conditional switch between `StandardView`, `TurntableView` (DJ), and `MinimalistView`.
- **`@Namespace`**: Shared between views to enable `matchedGeometryEffect` for elements like the play/pause button and waypoint dock.

### State Layer
- **`SpotifyController.swift`**:
    - `@Published var isMinimalistMode: Bool`
    - Logic to sync this state to `PlaybackStateManager` (App Groups).
- **`ToggleMinimalistIntent.swift`**:
    - A new `AppIntent` to allow external triggers (Shortcuts/Focus Modes) to toggle the mode.

## 3. UI/UX Design

### Layout (MinimalistView)
- **Background**: Reuses `BackgroundLayer` (Blurred Artwork).
- **Primary Controls**: 
    - A single maximized `HStack` in the center.
    - 3 Large Buttons: Skip Back, Play/Pause, Skip Forward.
    - Height: ~120pt to 150pt per button.
- **Waypoint Dock**: 
    - Scaled-up circular pins (2.5x original size).
    - Labels and timestamps hidden to minimize visual clutter.
    - Increased horizontal spacing.
- **Metadata**: Hides track/artist text and album art to focus entirely on interaction.

### Transitions
- **Morphing**: Using `matchedGeometryEffect` on the control symbols and the background layer.
- **Animation**: `.spring(response: 0.5, dampingFraction: 0.8)` for a tactile, physical feel.

## 4. Driving Focus Integration
- Users will be instructed (via a UI hint or README) to create an iOS Shortcut:
    - *Automation*: When "Driving" Focus is turned on.
    - *Action*: Run "Toggle Minimalist Mode" (Set to On).
    - *Automation*: When "Driving" Focus is turned off.
    - *Action*: Run "Toggle Minimalist Mode" (Set to Off).

## 5. Testing & Validation
- **Manual**: Toggle mode via Settings and verify layout scaling.
- **Functional**: Verify "Skip" and "Play/Pause" buttons remain responsive at larger scales.
- **Integration**: Run the AppIntent via the Shortcuts app to verify state changes in the main app.

---
*Created by Gemini CLI*
