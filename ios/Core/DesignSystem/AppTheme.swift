import SwiftUI
import UIKit

enum AppPalette {
    static let ink = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let inkSoft = Color(red: 0.38, green: 0.40, blue: 0.44)
    static let card = Color(red: 0.99, green: 0.98, blue: 0.97)
    static let shadow = Color(red: 0.15, green: 0.16, blue: 0.18, opacity: 0.08)
}

enum AppFont {
    static func avenir(_ size: CGFloat) -> Font {
        .custom("Avenir Next", size: size)
    }
}

enum AppHaptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
