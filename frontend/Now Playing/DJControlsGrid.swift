import SwiftUI

struct DJControlsGrid: View {
    @EnvironmentObject var spotifyController: SpotifyController
    
    let columns = [
        GridItem(.flexible()), GridItem(.flexible()), 
        GridItem(.flexible()), GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            // Hot Cues (Pads 1-6)
            ForEach(0..<6) { index in
                HotCuePad(index: index)
            }
            
            // Loop Controls (Pads 7-8)
            LoopInPad()
            LoopOutPad()
        }
        .padding(.horizontal, 20)
    }
}

// Sub-views for the pads
struct HotCuePad: View {
    @EnvironmentObject var spotifyController: SpotifyController
    let index: Int
    
    var body: some View {
        Button(action: {
            if index < spotifyController.waypoints.count {
                spotifyController.seekToWaypoint(spotifyController.waypoints[index])
            } else {
                spotifyController.addWaypoint()
            }
        }) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(padColor)
                .frame(height: 60)
                .overlay(
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                )
                .shadow(radius: 2)
        }
        .accessibilityLabel("Hot Cue \(index + 1)")
        .accessibilityValue(index < spotifyController.waypoints.count ? "Set, \(spotifyController.waypoints[index].position.formatAsTime())" : "Empty, tap to set")
        .contextMenu {
            if index < spotifyController.waypoints.count {
                Button(role: .destructive) {
                    spotifyController.removeWaypoint(spotifyController.waypoints[index])
                } label: {
                    Label("Clear Hot Cue", systemImage: "trash")
                }
            }
        }
    }
    
    private var padColor: Color {
        if index < spotifyController.waypoints.count {
            return Color(hex: spotifyController.waypoints[index].colorHex) ?? .blue
        }
        return .white.opacity(0.1) // Empty state
    }
}

struct LoopInPad: View {
    @EnvironmentObject var spotifyController: SpotifyController
    
    var body: some View {
        Button(action: { spotifyController.setLoopIn() }) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(spotifyController.loopStart != nil ? Color.stateMarkerOrange : .white.opacity(0.1))
                .frame(height: 60)
                .overlay(
                    VStack(spacing: 2) {
                        if spotifyController.loopStart != nil {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                        }
                        Text("IN").font(.caption.bold())
                    }
                    .foregroundColor(.inkPrimary)
                )
                .shadow(radius: 2)
        }
        .accessibilityLabel("Loop In Point")
        .accessibilityValue(spotifyController.loopStart != nil ? "Set" : "Not set")
        .accessibilityAddTraits(spotifyController.loopStart != nil ? .isSelected : [])
    }
}

struct LoopOutPad: View {
    @EnvironmentObject var spotifyController: SpotifyController
    
    var body: some View {
        Button(action: {
            if spotifyController.loopEnd != nil {
                spotifyController.clearLoop()
            } else {
                spotifyController.setLoopOut()
            }
        }) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(spotifyController.loopEnd != nil ? Color.stateMarkerOrange : .white.opacity(0.1))
                .frame(height: 60)
                .overlay(
                    Text(spotifyController.loopEnd != nil ? "CLEAR" : "OUT")
                        .font(.caption.bold())
                        .foregroundColor(.inkPrimary)
                )
                .shadow(radius: 2)
        }
        .accessibilityLabel(spotifyController.loopEnd != nil ? "Clear Loop" : "Loop Out Point")
        .accessibilityValue(spotifyController.loopEnd != nil ? "Set" : "Not set")
        .accessibilityAddTraits(spotifyController.loopEnd != nil ? .isSelected : [])
    }
}

#Preview {
    DJControlsGrid()
        .environmentObject(SpotifyController.shared)
        .background(Color.black)
}
