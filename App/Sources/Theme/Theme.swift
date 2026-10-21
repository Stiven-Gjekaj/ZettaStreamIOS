import SwiftUI
import UIKit

/// A black and white palette. Red is only for errors.
enum Palette {
    static let background = Color(red: 0, green: 0, blue: 0)
    static let surface = Color(white: 0x0E / 255)
    static let surfaceHigh = Color(white: 0x18 / 255)
    static let outline = Color(white: 0x2E / 255)
    static let accent = Color.white
    static let onAccent = Color.black
    static let textPrimary = Color(white: 0xF2 / 255)
    static let textSecondary = Color(white: 0x8C / 255)
    static let danger = Color(red: 1, green: 0x6B / 255, blue: 0x6B / 255)
}

/// One corner radius for every card, button, and chip.
let corner: CGFloat = 8

/// Karla, the font of Miruro 2.0, under the SIL Open Font License.
/// One variable file gives each weight, so the weight goes to the `wght` axis.
enum Karla {
    private static let weightAxis = 0x7767_6874

    /// The size follows Dynamic Type: SwiftUI scales it with `style` each time the setting changes.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom("Karla-Regular", size: size, relativeTo: style).weight(weight)
    }

    static func uiFont(_ size: CGFloat, _ weight: Font.Weight) -> UIFont {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "Karla-Regular",
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [weightAxis: weight.axisValue],
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
}

private extension Font.Weight {
    var axisValue: CGFloat {
        switch self {
        case .ultraLight, .thin: 200
        case .light: 300
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy, .black: 800
        default: 400
        }
    }
}

extension View {
    /// The look of every screen: black, with light text.
    func zettaScreen() -> some View {
        background(Palette.background.ignoresSafeArea())
            .foregroundStyle(Palette.textPrimary)
            .preferredColorScheme(.dark)
            .tint(Palette.accent)
    }
}
