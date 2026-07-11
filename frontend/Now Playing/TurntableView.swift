import SwiftUI

struct TurntableView: View {
    @EnvironmentObject var spotifyController: SpotifyController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    let trackImage: UIImage
    let namespace: Namespace.ID

    // Timer to drive the rotation when not paused. `@State` so SwiftUI preserves a single
    // instance across body re-evaluations instead of re-creating the Combine publisher chain
    // on every redraw (this view's parent redraws roughly once per second from position ticks).
    @State private var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        Image(uiImage: trackImage)
            .resizable()
            .scaledToFill()
            .frame(width: 250, height: 250)
            .clipShape(Circle())
            .overlay(
                // Center spindle hole
                Circle()
                    .fill(Color.voidBlack)
                    .frame(width: 15, height: 15)
            )
            .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 10)
            .matchedGeometryEffect(id: "albumArt", in: namespace)
            .rotationEffect(.degrees(rotation))
            .onReceive(timer) { _ in
                // A continuously spinning disc is exactly the kind of motion Reduce Motion
                // should stop outright, not just slow down — so it doesn't spin at all here.
                if !spotifyController.isPaused && !reduceMotion {
                    rotation += 2.0 // Rotate 2 degrees every 0.05s
                }
            }
            .accessibilityLabel("Album art")
            .trackTransition(id: spotifyController.currentTrackURI, duration: 0.4)
    }
}

#Preview {
    @Previewable @Namespace var ns
    TurntableView(trackImage: UIImage(systemName: "music.note")!, namespace: ns)
        .environmentObject(SpotifyController.shared)
        .background(Color.voidBlack)
}
