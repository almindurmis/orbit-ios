import SpriteKit

enum Palette {
    static let background = SKColor(red: 0.027, green: 0.031, blue: 0.078, alpha: 1)
    static let gold = SKColor(red: 1.0, green: 0.84, blue: 0.42, alpha: 1)
    static let cyan = SKColor(red: 0.32, green: 0.9, blue: 1.0, alpha: 1)
    static let shieldBlue = SKColor(red: 0.35, green: 0.78, blue: 1.0, alpha: 1)
    static let magnetViolet = SKColor(red: 0.72, green: 0.5, blue: 1.0, alpha: 1)
    static let unstableRed = SKColor(red: 1.0, green: 0.45, blue: 0.35, alpha: 1)
    static let bouncerPink = SKColor(red: 1.0, green: 0.42, blue: 0.76, alpha: 1)
    static let textPrimary = SKColor.white
    static let textDim = SKColor(white: 1, alpha: 0.45)

    // Planets stay inside their sector's hue family, drifting a little per planet
    // so a chain reads varied but the sector still has one identity.
    private static let hueDrifts: [CGFloat] = [0, 0.06, -0.06, 0.11, -0.11, 0.04]

    static func planetColor(index: Int, sectorHue: CGFloat) -> SKColor {
        var hue = (sectorHue + hueDrifts[index % hueDrifts.count]).truncatingRemainder(dividingBy: 1)
        if hue < 0 { hue += 1 }
        return SKColor(hue: hue, saturation: 0.68, brightness: 1.0, alpha: 1)
    }
}
