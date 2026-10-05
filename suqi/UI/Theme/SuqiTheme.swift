//
//  SuqiTheme.swift
//  suqi
//
//  Created for suqi Terminal.
//

import SwiftUI
import AppKit
import GhosttyTheme

public typealias SuqiThemeCatalog = GhosttyThemeCatalog
public typealias SuqiThemeDefinition = GhosttyThemeDefinition

public enum SuqiTheme {
    public static let defaultBackgroundHex = "30333E"

    public static func backgroundColor(for themeName: String, customBackground: String? = nil) -> Color {
        if let customBackground, !customBackground.trimmingCharacters(in: .whitespaces).isEmpty {
            return Color(hex: customBackground)
        }
        if let theme = SuqiThemeCatalog.theme(named: themeName) {
            return Color(hex: theme.background)
        }
        return Color(hex: defaultBackgroundHex)
    }

    public static func nsBackgroundColor(for themeName: String, customBackground: String? = nil) -> NSColor {
        if let customBackground, !customBackground.trimmingCharacters(in: .whitespaces).isEmpty {
            return NSColor(hex: customBackground)
        }
        if let theme = SuqiThemeCatalog.theme(named: themeName) {
            return NSColor(hex: theme.background)
        }
        return NSColor(hex: defaultBackgroundHex)
    }
}

// MARK: - Color Hex Extensions

public extension Color {
    init(hex: String, defaultColor: Color = Color(red: 48/255.0, green: 51/255.0, blue: 62/255.0)) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        if Scanner(string: clean).scanHexInt64(&int) {
            let r, g, b: Double
            switch clean.count {
            case 6:
                r = Double((int >> 16) & 0xFF) / 255.0
                g = Double((int >> 8) & 0xFF) / 255.0
                b = Double(int & 0xFF) / 255.0
                self.init(red: r, green: g, blue: b)
                return
            default:
                break
            }
        }
        self = defaultColor
    }
}

public extension NSColor {
    convenience init(hex: String, defaultColor: NSColor = NSColor(srgbRed: 48/255.0, green: 51/255.0, blue: 62/255.0, alpha: 1.0)) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        if Scanner(string: clean).scanHexInt64(&int) {
            let r, g, b: CGFloat
            switch clean.count {
            case 6:
                r = CGFloat((int >> 16) & 0xFF) / 255.0
                g = CGFloat((int >> 8) & 0xFF) / 255.0
                b = CGFloat(int & 0xFF) / 255.0
                self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
                return
            default:
                break
            }
        }
        self.init(cgColor: defaultColor.cgColor)!
    }
}
