import SpriteKit

enum Palette {
    static let background = SKColor(red: 0.027, green: 0.031, blue: 0.078, alpha: 1)
    static let gold = SKColor(red: 1.0, green: 0.84, blue: 0.42, alpha: 1)
    static let cyan = SKColor(red: 0.32, green: 0.9, blue: 1.0, alpha: 1)
    static let shieldBlue = SKColor(red: 0.35, green: 0.78, blue: 1.0, alpha: 1)
    static let magnetViolet = SKColor(red: 0.72, green: 0.5, blue: 1.0, alpha: 1)
    static let unstableRed = SKColor(red: 1.0, green: 0.45, blue: 0.35, alpha: 1)
    static let textPrimary = SKColor.white
    static let textDim = SKColor(white: 1, alpha: 0.45)

    // Neon hues cycled as the planet chain grows, so long runs drift through the spectrum.
    private static let hues: [CGFloat] = [0.52, 0.58, 0.68, 0.78, 0.87, 0.94, 0.07, 0.36, 0.45]

    static func planetColor(index: Int) -> SKColor {
        SKColor(hue: hues[index % hues.count], saturation: 0.68, brightness: 1.0, alpha: 1)
    }
}
