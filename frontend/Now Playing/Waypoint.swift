//
//  Waypoint.swift
//  Now Playing
//

import Foundation
import SwiftUI
import UIKit

struct Waypoint: Identifiable, Codable, Equatable {
    let id: UUID
    let position: Int // in seconds
    let colorHex: String
    var label: String?

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    init(id: UUID = UUID(), position: Int, colorHex: String, label: String? = nil) {
        self.id = id
        self.position = position
        self.colorHex = colorHex
        self.label = label
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            red = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            green = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            blue = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            alpha = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }

    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let red = Float(components[0])
        let green = Float(components[1])
        let blue = Float(components[2])
        var alpha = Float(1.0)

        if components.count >= 4 {
            alpha = Float(components[3])
        }

        if alpha != 1.0 {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255), lroundf(alpha * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255))
        }
    }
}
