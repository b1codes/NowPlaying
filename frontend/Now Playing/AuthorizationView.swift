//
//  AuthorizationView.swift
//  Now Playing
//
//  Created by Brandon Lamer-Connolly on 1/3/26.
//

import SwiftUI

struct AuthorizationView: View {
    @EnvironmentObject var spotifyController: SpotifyController

    var body: some View {
        VStack(spacing: 16) {
            Image("AppIcon")
                .resizable()
                .cornerRadius(30.0)
                .scaledToFill()
                .frame(width: 200, height: 200)
                .padding()

            Button("Connect to Spotify") {
                spotifyController.authorize()
            }
            .font(.headline)
            .padding()
            // White text on system green measures ~2.2:1 — well under the 4.5:1 WCAG AA
            // minimum for this app's very first interactive control. Black text on the
            // same green passes comfortably (~9.6:1) and matches Spotify's own convention
            // of dark text on their brand green.
            .foregroundColor(.black)
            .background(Color.green)
            .cornerRadius(CornerRadius.lg)
            .accessibilityLabel("Connect to Spotify")

            if spotifyController.connectionState == .failed {
                Text("Could not connect to Spotify.\nMake sure the Spotify app is open.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: spotifyController.connectionState == .failed)
    }
}

#Preview {
    AuthorizationView()
        .environmentObject(SpotifyController())
}
