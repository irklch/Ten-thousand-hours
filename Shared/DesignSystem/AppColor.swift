import SwiftUI

enum AppColor {
    static let background = Color(hex: 0xFFFFFF)
    static let primaryText = Color(hex: 0x000000)
    static let secondaryText = Color(hex: 0x8A8A8E)
    static let activeDot = Color(hex: 0x000000)
    static let inactiveDot = Color(hex: 0xE8E8ED)
    static let separator = Color(hex: 0xD1D1D6)
    static let onPrimary = Color(hex: 0xFFFFFF)
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
