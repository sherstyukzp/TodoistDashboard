import SwiftUI

// MARK: - App Theme

enum AppTheme {
    // Main palette
    static let accent = Color("AccentColor")
    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let secondaryText = Color(.secondaryLabel)

    // Priority colors
    static let p1 = Color(hex: "D1453B")  // Red — urgent
    static let p2 = Color(hex: "EB8909")  // Orange — high
    static let p3 = Color(hex: "246FE0")  // Blue — medium
    static let p4 = Color(.tertiaryLabel)  // Gray — normal

    // Status colors
    static let success = Color(hex: "058527")
    static let warning = Color(hex: "EB8909")
    static let danger = Color(hex: "D1453B")

    // Chart palette
    static let chartColors: [Color] = [
        Color(hex: "246FE0"),
        Color(hex: "EB8909"),
        Color(hex: "058527"),
        Color(hex: "A970FF"),
        Color(hex: "D1453B"),
        Color(hex: "14AAF5"),
        Color(hex: "FF8D85"),
        Color(hex: "6ACCBC"),
    ]

    static func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 4: return p1  // API: 4 = p1 (urgent)
        case 3: return p2  // API: 3 = p2
        case 2: return p3  // API: 2 = p3
        default: return p4 // API: 1 = p4 (normal)
        }
    }

    static func priorityLabel(for priority: Int) -> String {
        switch priority {
        case 4: return "P1"
        case 3: return "P2"
        case 2: return "P3"
        default: return "P4"
        }
    }

    // Todoist project colors
    static let todoistColors: [String: Color] = [
        "berry_red": Color(hex: "B8255F"),
        "red": Color(hex: "DB4035"),
        "orange": Color(hex: "FF9933"),
        "yellow": Color(hex: "FAD000"),
        "olive_green": Color(hex: "AFB83B"),
        "lime_green": Color(hex: "7ECC49"),
        "green": Color(hex: "299438"),
        "mint_green": Color(hex: "6ACCBC"),
        "teal": Color(hex: "158FAD"),
        "sky_blue": Color(hex: "14AAF5"),
        "light_blue": Color(hex: "96C3EB"),
        "blue": Color(hex: "4073FF"),
        "grape": Color(hex: "884DFF"),
        "violet": Color(hex: "AF38EB"),
        "lavender": Color(hex: "EB96EB"),
        "magenta": Color(hex: "E05194"),
        "salmon": Color(hex: "FF8D85"),
        "charcoal": Color(hex: "808080"),
        "grey": Color(hex: "B8B8B8"),
        "taupe": Color(hex: "CCAC93"),
    ]

    static func projectColor(for colorName: String) -> Color {
        todoistColors[colorName] ?? Color(hex: "808080")
    }
}

// MARK: - Color Hex Extension

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
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
