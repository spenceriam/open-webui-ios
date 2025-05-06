import SwiftUI

/// Color theme designed to match Open WebUI web application
struct ColorTheme {
    // MARK: - Light Theme Colors
    static let backgroundLight = Color(hex: "#FFFFFF")
    static let secondaryBackgroundLight = Color(hex: "#F5F5F5")
    static let textLight = Color(hex: "#1A1A1A")
    static let secondaryTextLight = Color(hex: "#666666")
    static let accentLight = Color(hex: "#3B82F6") // Blue accent color
    
    // MARK: - Dark Theme Colors
    static let backgroundDark = Color(hex: "#1A1A1A")
    static let secondaryBackgroundDark = Color(hex: "#252525")
    static let textDark = Color(hex: "#F5F5F5")
    static let secondaryTextDark = Color(hex: "#AAAAAA")
    static let accentDark = Color(hex: "#60A5FA") // Lighter blue for dark mode
    
    // MARK: - Brand Colors
    static let primaryBlue = Color(hex: "#3B82F6")
    static let secondaryPurple = Color(hex: "#8B5CF6")
    static let successGreen = Color(hex: "#22C55E")
    static let warningYellow = Color(hex: "#EAB308")
    static let errorRed = Color(hex: "#EF4444")
    
    // MARK: - Dynamic Colors (adapts to light/dark mode)
    static func background(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundDark : backgroundLight
    }
    
    static func secondaryBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? secondaryBackgroundDark : secondaryBackgroundLight
    }
    
    static func text(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textDark : textLight
    }
    
    static func secondaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? secondaryTextDark : secondaryTextLight
    }
    
    static func accent(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? accentDark : accentLight
    }
}

// Extension to create Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}