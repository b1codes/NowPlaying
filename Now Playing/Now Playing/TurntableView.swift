import SwiftUI

struct TurntableView: View {
    @EnvironmentObject var spotifyController: SpotifyController
    @State private var rotation: Double = 0
    let trackImage: UIImage
    
    // Timer to drive the rotation when not paused
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Image(uiImage: trackImage)
            .resizable()
            .scaledToFill()
            .frame(width: 250, height: 250)
            .clipShape(Circle())
            .overlay(
                // Center spindle hole
                Circle()
                    .fill(Color.black)
                    .frame(width: 15, height: 15)
            )
            .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 10)
            .rotationEffect(.degrees(rotation))
            .onReceive(timer) { _ in
                if !spotifyController.isPaused {
                    rotation += 2.0 // Rotate 2 degrees every 0.05s
                }
            }
            .trackTransition(id: spotifyController.currentTrackURI, duration: 0.4)
    }
}

#Preview {
    TurntableView(trackImage: UIImage(systemName: "music.note")!)
        .environmentObject(SpotifyController.shared)
        .background(Color.black)
}
