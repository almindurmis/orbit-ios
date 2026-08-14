import Foundation
import SpriteKit

// Persistent pilot progression: every run's score becomes XP, across classic
// and daily alike. Levels unlock trail colors every 5 pilot levels.
enum Progress {
    private static let key = "progress.xp"

    static var xp: Int { UserDefaults.standard.integer(forKey: key) }

    // Each pilot level costs a bit more than the last: 40, 60, 80, ...
    static func cost(ofLevel level: Int) -> Int { 40 + (level - 1) * 20 }

    static var level: Int { split(xp).level }

    static var xpIntoLevel: Int { split(xp).into }

    static var xpForNextLevel: Int { cost(ofLevel: level) }

    private static func split(_ xp: Int) -> (level: Int, into: Int) {
        var remaining = xp
        var level = 1
        while remaining >= cost(ofLevel: level) {
            remaining -= cost(ofLevel: level)
            level += 1
        }
        return (level, remaining)
    }

    // Returns true when the added XP crossed at least one level boundary.
    @discardableResult
    static func addXP(_ amount: Int) -> Bool {
        guard amount > 0 else { return false }
        let before = level
        UserDefaults.standard.set(xp + amount, forKey: key)
        return level > before
    }

    static let trailTiers: [(level: Int, color: SKColor)] = [
        (1, .white),
        (5, Palette.cyan),
        (10, SKColor(red: 0.45, green: 1.0, blue: 0.6, alpha: 1)),
        (15, Palette.gold),
        (20, Palette.magnetViolet),
        (25, SKColor(red: 1.0, green: 0.55, blue: 0.8, alpha: 1)),
        (30, SKColor(red: 1.0, green: 0.5, blue: 0.35, alpha: 1)),
    ]

    // MARK: - Hangar selections (chosen look persists; locked picks fall back)

    private static let trailChoiceKey = "progress.trailChoice"
    private static let shipChoiceKey = "progress.ship"

    /// The trail tier level the pilot picked in the Hangar (0 = auto: highest unlocked).
    static var selectedTrailLevel: Int {
        get { UserDefaults.standard.integer(forKey: trailChoiceKey) }
        set { UserDefaults.standard.set(newValue, forKey: trailChoiceKey) }
    }

    static var trailColor: SKColor {
        let choice = selectedTrailLevel
        if choice > 0, level >= choice,
           let tier = trailTiers.first(where: { $0.level == choice }) {
            return tier.color
        }
        return trailTiers.last(where: { level >= $0.level })?.color ?? .white
    }

    static var unlockedNewTrail: Bool {
        trailTiers.contains(where: { $0.level == level })
    }

    static var selectedShip: ShipStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: shipChoiceKey),
                  let ship = ShipStyle(rawValue: raw),
                  level >= ship.unlockLevel else { return .classic }
            return ship
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: shipChoiceKey) }
    }

    static var unlockedNewShip: Bool {
        ShipStyle.allCases.contains(where: { $0.unlockLevel == level })
    }
}

// Orbiter looks unlocked by pilot level, chosen in the Hangar (tap the pilot
// card on the menu). Each restyles the core + halo; the trail color is a
// separate pick so combinations are the player's own.
enum ShipStyle: String, CaseIterable {
    case classic, comet, ember, crystal, void, nova

    var unlockLevel: Int {
        switch self {
        case .classic: return 1
        case .comet: return 3
        case .ember: return 8
        case .crystal: return 12
        case .void: return 18
        case .nova: return 24
        }
    }

    var displayName: String {
        switch self {
        case .classic: return "CLASSIC"
        case .comet: return "COMET"
        case .ember: return "EMBER"
        case .crystal: return "CRYSTAL"
        case .void: return "VOID"
        case .nova: return "NOVA"
        }
    }

    var coreColor: SKColor {
        switch self {
        case .classic: return .white
        case .comet: return SKColor(red: 0.85, green: 0.97, blue: 1.0, alpha: 1)
        case .ember: return SKColor(red: 1.0, green: 0.62, blue: 0.3, alpha: 1)
        case .crystal: return SKColor(red: 0.62, green: 0.88, blue: 1.0, alpha: 1)
        case .void: return SKColor(red: 0.07, green: 0.07, blue: 0.14, alpha: 1)
        case .nova: return Palette.gold
        }
    }

    var haloColor: SKColor {
        switch self {
        case .classic: return .white
        case .comet: return Palette.cyan
        case .ember: return SKColor(red: 1.0, green: 0.45, blue: 0.2, alpha: 1)
        case .crystal: return SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1)
        case .void: return SKColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1)
        case .nova: return Palette.gold
        }
    }
}
