import SwiftUI

// Shared "terminal/code" look: monospaced everywhere technical, a distinct
// accent color per card so the popover doesn't read as one flat gray block.
enum Theme {
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    enum Accent {
        static let quality = Color.purple
        static let nowPlaying = Color.pink
        static let transfer = Color.green
        static let device = Color.orange
        static let logs = Color.mint
    }
}
