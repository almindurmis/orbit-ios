import SpriteKit

// Every level is a named "sector" with its own hue family: the background wash,
// the planet palette and the level banner all follow it, so climbing visibly
// changes the world instead of just shrinking rings.
struct Sector {
    let level: Int
    let name: String
    let hue: CGFloat

    var color: SKColor {
        SKColor(hue: hue, saturation: 0.65, brightness: 1.0, alpha: 1)
    }
}

enum Sectors {
    // Order matters: level 1 keeps the game's familiar cyan-ish home look.
    private static let names: [String] = [
        "HOME NEBULA", "CRIMSON DRIFT", "AZURE EXPANSE", "EMBER FIELDS",
        "VIOLET DEEP", "JADE HOLLOW", "GOLDEN REACH", "FROST VEIL",
        "MAGMA BELT", "ECHO RIM", "SHADOW SPIRAL", "IRIS BLOOM",
    ]
    private static let hues: [CGFloat] = [
        0.55, 0.97, 0.60, 0.07,
        0.75, 0.38, 0.12, 0.52,
        0.02, 0.63, 0.80, 0.90,
    ]

    static func sector(for level: Int) -> Sector {
        let i = (level - 1) % names.count
        return Sector(level: level, name: names[i], hue: hues[i])
    }
}
