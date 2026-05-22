//
//  Now_PlayingApp.swift
//  Now Playing
//
//  Created by Brandon Lamer-Connolly on 10/25/23.
//

import SwiftUI

@main
struct NowPlayingApp: App {
    @StateObject var spotifyController = SpotifyController.shared

    init() {
        PlaybackControlProvider.shared = SpotifyController.shared
    }

    var body: some Scene {
        WindowGroup {
            // Logic to switch views based on connection/playback state
            Group {
                if spotifyController.currentTrackName != nil {
                    ContentView()
                } else {
                    AuthorizationView()
                }
            }
            .environmentObject(spotifyController)
            .onOpenURL { url in
                spotifyController.setAccessToken(from: url)
            }
        }
    }
}
