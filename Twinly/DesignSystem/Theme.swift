// Theme — Twinly's design tokens. "Ink and champagne": a near-black ink
// canvas, solid charcoal surfaces, warm champagne for you (and for primary
// actions and star moments), cool steel blue for your famous twin. Flat
// colour only: no gradients, glows or blurred colour washes. Reference these
// instead of ad-hoc values.

import SwiftUI

enum Theme {
    enum Palette {
        static let night = Color(hex: 0x111214)        // canvas
        static let surface = Color(hex: 0x1B1C20)      // cards, secondary buttons, placeholders
        static let raised = Color(hex: 0x262830)       // a step above surface
        static let stroke = Color(hex: 0x33353B)       // hairlines and outlines
        static let accent = Color(hex: 0xD9B26F)       // champagne: you, primary actions, stars
        static let star = Color(hex: 0x9DB2CF)         // steel blue: the famous twin
        static let onAccent = Color(hex: 0x1A1610)     // text on champagne
        static let textPrimary = Color(hex: 0xF3EFE7)
        static let textSecondary = Color(hex: 0xA9A6A0)
        static let textTertiary = Color(hex: 0x76736D)
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let s: CGFloat = 12
        static let m: CGFloat = 20
        static let l: CGFloat = 28
    }

    enum Font {
        static let display = SwiftUI.Font.system(size: 40, weight: .bold, design: .serif)
        static let name = SwiftUI.Font.system(size: 34, weight: .bold, design: .serif)
        static let title = SwiftUI.Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = SwiftUI.Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = SwiftUI.Font.system(size: 16, weight: .regular, design: .rounded)
        static let caption = SwiftUI.Font.system(size: 13, weight: .medium, design: .rounded)
        static let overline = SwiftUI.Font.system(size: 12, weight: .bold, design: .rounded)
        static let percent = SwiftUI.Font.system(size: 22, weight: .heavy, design: .rounded)
    }

    enum Motion {
        static let snappy = Animation.spring(response: 0.38, dampingFraction: 0.82)
        static let soft = Animation.spring(response: 0.6, dampingFraction: 0.86)
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.62)
        static let slow = Animation.easeInOut(duration: 1.2)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
