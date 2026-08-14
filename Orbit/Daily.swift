import Foundation

// Daily challenge state: one seeded run per calendar day, streak of consecutive played days.
enum Daily {
    private static let lastPlayedKey = "daily.lastPlayedDay"
    private static let streakKey = "daily.streak"
    private static let bestKey = "daily.best"
    private static let bestDayKey = "daily.bestDay"

    static var todayKey: Int { key(for: Date()) }

    static func key(for date: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return c.year! * 10000 + c.month! * 100 + c.day!
    }

    static var seed: UInt64 { UInt64(todayKey) }

    // Some days the daily gets a twist — deterministic from the date, so the
    // whole world plays the same mutation.
    enum Mutator: String {
        case tinyRings = "TINY RINGS"
        case hyper = "HYPER ORBITS"
    }

    static var mutator: Mutator? {
        switch todayKey % 5 {
        case 1: return .tinyRings
        case 3: return .hyper
        default: return nil
        }
    }

    private static var yesterdayKey: Int {
        key(for: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
    }

    // Playing at least one daily run keeps the streak alive; a missed day resets it.
    @discardableResult
    static func registerPlay() -> Int {
        let defaults = UserDefaults.standard
        let today = todayKey
        let last = defaults.integer(forKey: lastPlayedKey)
        if last == today { return defaults.integer(forKey: streakKey) }
        let streak = last == yesterdayKey ? defaults.integer(forKey: streakKey) + 1 : 1
        defaults.set(streak, forKey: streakKey)
        defaults.set(today, forKey: lastPlayedKey)
        return streak
    }

    static var currentStreak: Int {
        let defaults = UserDefaults.standard
        let last = defaults.integer(forKey: lastPlayedKey)
        guard last == todayKey || last == yesterdayKey else { return 0 }
        return defaults.integer(forKey: streakKey)
    }

    static var bestToday: Int {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: bestDayKey) == todayKey else { return 0 }
        return defaults.integer(forKey: bestKey)
    }

    static func recordScore(_ score: Int) {
        guard score > bestToday else { return }
        let defaults = UserDefaults.standard
        defaults.set(todayKey, forKey: bestDayKey)
        defaults.set(score, forKey: bestKey)
    }
}
