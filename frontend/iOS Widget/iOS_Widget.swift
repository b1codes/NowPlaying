//
//  iOS_Widget.swift
//  iOS Widget
//
//  Created by Brandon Lamer-Connolly on 8/30/25.
//

import WidgetKit
import SwiftUI
import AppIntents

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), state: .empty, image: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let state = PlaybackStateManager.shared.load()
        let image = PlaybackStateManager.shared.loadImage()
        let entry = SimpleEntry(date: Date(), state: state, image: image)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let state = PlaybackStateManager.shared.load()
        let image = PlaybackStateManager.shared.loadImage()
        let entry = SimpleEntry(date: Date(), state: state, image: image)

        // Refresh every 15 minutes if no updates come in
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let state: PlaybackState
    let image: UIImage?
}

struct IOSWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.secondary)
                        )
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.state.trackName)
                        .font(.system(.subheadline, weight: .bold))
                        .lineLimit(1)
                    Text(entry.state.artistName)
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 24) {
                Button(intent: SkipPreviousIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Button(intent: PlayPauseIntent()) {
                    Image(systemName: entry.state.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)

                Button(intent: SkipNextIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .containerBackground(for: .widget) {
            ZStack {
                Color.black.opacity(0.1)
                if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 20)
                        .opacity(0.4)
                }
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}

struct IOSWidget: Widget {
    let kind: String = "iOS_Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            IOSWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("Control your Spotify playback.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    IOSWidget()
} timeline: {
    SimpleEntry(date: Date(), state: .empty, image: nil)
}
