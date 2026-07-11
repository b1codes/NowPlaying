//
//  DesignTokens.swift
//  Now Playing
//
//  Palette and corner-radius scale extracted from DESIGN.md. Route new colors/radii through
//  these instead of raw literals, per DESIGN.md's own "Don't hardcode a hex color or point
//  size directly in a view" rule — a future LLC typeface/Thermal-Glow migration should only
//  need to touch this one file.
//

import SwiftUI

extension Color {
    // MARK: Ink ramp (text/icon hierarchy) — DESIGN.md §2 Neutral
    static let inkPrimary = Color.white
    static let inkSecondary = Color.white.opacity(0.9)
    static let inkMuted = Color.white.opacity(0.7)
    static let inkFaint = Color.white.opacity(0.6)

    // MARK: Base surfaces — DESIGN.md §2 Primary / Neutral
    static let voidBlack = Color.black
    static let pureWhite = Color.white

    // MARK: Glass card — DESIGN.md §2 Neutral, §5 Glass Card
    static let glassTint = Color.white.opacity(0.10)
    static let glassBorderStart = Color.white.opacity(0.5)
    static let glassBorderEnd = Color.clear

    // MARK: State & signal — DESIGN.md §2 State & Signal
    static let stateActiveGreen = Color.green
    static let stateMarkerOrange = Color.orange
}

/// Corner-radius scale from DESIGN.md's `rounded` tokens.
enum CornerRadius {
    static let sm: CGFloat = 8   // DJ grid pads
    static let md: CGFloat = 10  // waypoint dock chips
    static let lg: CGFloat = 20  // album art, primary buttons
    static let xl: CGFloat = 35  // the glass card itself
}
