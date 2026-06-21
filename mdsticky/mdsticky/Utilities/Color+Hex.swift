//
//  Color+Hex.swift
//  mdsticky
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        let nsColor = NSColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: CGFloat
        switch hex.count {
        case 3:
            (a, r, g, b) = (1.0, CGFloat((int >> 8) * 17) / 255, CGFloat((int >> 4 & 0xF) * 17) / 255, CGFloat((int & 0xF) * 17) / 255)
        case 6:
            (a, r, g, b) = (1.0, CGFloat(int >> 16) / 255, CGFloat(int >> 8 & 0xFF) / 255, CGFloat(int & 0xFF) / 255)
        case 8:
            (a, r, g, b) = (CGFloat(int >> 24) / 255, CGFloat(int >> 16 & 0xFF) / 255, CGFloat(int >> 8 & 0xFF) / 255, CGFloat(int & 0xFF) / 255)
        default:
            (a, r, g, b) = (1.0, 0, 0, 0)
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

enum NoteColor: String, CaseIterable {
    case yellow = "#FFEB3B"
    case green = "#C8E6C9"
    case blue = "#BBDEFB"
    case pink = "#F8BBD0"
    case orange = "#FFE0B2"
    case purple = "#E1BEE7"
    case gray = "#F5F5F5"

    var swiftUIColor: Color { Color(hex: rawValue) }
    var nsColor: NSColor { NSColor(hex: rawValue) }
    var name: String {
        switch self {
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        case .pink: return "粉色"
        case .orange: return "橙色"
        case .purple: return "紫色"
        case .gray: return "灰色"
        }
    }
}
