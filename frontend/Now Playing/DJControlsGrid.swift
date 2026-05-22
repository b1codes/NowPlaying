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
            RoundedRectangle(cornerRadius: 8)
                .fill(padColor)
                .frame(height: 60)
                .overlay(
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                )
                .shadow(radius: 2)
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
            RoundedRectangle(cornerRadius: 8)
                .fill(spotifyController.loopStart != nil ? Color.orange : .white.opacity(0.1))
                .frame(height: 60)
                .overlay(Text("IN").font(.caption.bold()).foregroundColor(.white))
                .shadow(radius: 2)
        }
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
            RoundedRectangle(cornerRadius: 8)
                .fill(spotifyController.loopEnd != nil ? Color.orange : .white.opacity(0.1))
                .frame(height: 60)
                .overlay(
                    Text(spotifyController.loopEnd != nil ? "CLEAR" : "OUT")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                )
                .shadow(radius: 2)
        }
    }
}

#Preview {
    DJControlsGrid()
        .environmentObject(SpotifyController.shared)
        .background(Color.black)
}
