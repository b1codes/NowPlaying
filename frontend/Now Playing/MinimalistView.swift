//
//  MinimalistView.swift
//  Now Playing
//
//  Created by Brandon Lamer-Connolly on 5/2/26.
//

import SwiftUI

struct MinimalistView: View {
    @EnvironmentObject var spotifyController: SpotifyController
    let namespace: Namespace.ID
    
    var body: some View {
        VStack {
            Spacer()
            
            // MARK: - Main Controls
            HStack(spacing: 40) {
                Button(action: { spotifyController.skipToPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.inkPrimary)
                }
                .matchedGeometryEffect(id: "skipBack", in: namespace)
                .accessibilityLabel("Previous Track")

                Button(action: {
                    spotifyController.isPaused ? spotifyController.play() : spotifyController.pause()
                }) {
                    Image(systemName: spotifyController.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.inkPrimary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .matchedGeometryEffect(id: "playPause", in: namespace)
                .accessibilityLabel(spotifyController.isPaused ? "Play" : "Pause")

                Button(action: { spotifyController.skipToNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.inkPrimary)
                }
                .matchedGeometryEffect(id: "skipForward", in: namespace)
                .accessibilityLabel("Next Track")
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
            .glassBackground()
            
            Spacer()
            
            // Large Waypoint Dock
            if !spotifyController.waypoints.isEmpty {
                MinimalistWaypointDock(namespace: namespace)
                    .padding(.bottom, 50)
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))
            }
        }
        .padding()
        .environment(\.colorScheme, .dark)
    }
}

struct MinimalistWaypointDock: View {
    @EnvironmentObject var spotifyController: SpotifyController
    let namespace: Namespace.ID
    
    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(spotifyController.waypoints) { waypoint in
                        Button(action: { spotifyController.seekToWaypoint(waypoint) }) {
                            Circle()
                                .fill(waypoint.color)
                                .frame(width: 40, height: 40)
                                .shadow(color: waypoint.color.opacity(0.5), radius: 8)
                                .matchedGeometryEffect(id: "waypointCircle-\(waypoint.id.uuidString)", in: namespace)
                        }
                        // The visible circle stays 40px per DESIGN.md's documented Waypoint
                        // Marker spec; only the invisible tappable region grows to the 44pt
                        // minimum touch target — the one place this matters most, since this
                        // is the driving-mode dock.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("\(waypoint.colorName) waypoint")
                        .accessibilityValue(waypoint.position.formatAsTime())
                    }
                }
                .padding(.horizontal, 25)
            }
            .frame(height: 60)
        }
        .padding(.vertical, 15)
        .glassBackground()
        .matchedGeometryEffect(id: "waypointDock", in: namespace)
    }
}

#Preview {
    @Previewable @Namespace var ns
    MinimalistView(namespace: ns)
        .environmentObject(SpotifyController.shared)
        .background(Color.black)
}
