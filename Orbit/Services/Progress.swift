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

    static var trailColor: SKColor {
        trailTiers.last(where: { level >= $0.level })?.color ?? .white
    }

    static var unlockedNewTrail: Bool {
        trailTiers.contains(where: { $0.level == level })
    }
}
