import Foundation

// Three seeded daily missions — same set for the whole day, fully offline.
// Run-scoped kinds track your best single run; day-scoped kinds accumulate
// across runs. Completing a mission pays pilot XP once.
enum Missions {
    enum Kind: Int, CaseIterable {
        case perfectsInRun      // land N PERFECTs in one run
        case capturesInRun      // capture N planets in one run
        case scoreInRun         // score N points in one run
        case reachSector        // reach sector N in one run
        case bouncesToday       // ricochet off N bouncers today (all runs)
        case closeCallsToday    // graze N asteroid walls today (all runs)

        var isCumulative: Bool { self == .bouncesToday || self == .closeCallsToday }
    }

    struct Mission {
        let index: Int
        let kind: Kind
        let target: Int
        let xp: Int

        var title: String {
            switch kind {
            case .perfectsInRun: return "\(target) PERFECTS IN A RUN"
            case .capturesInRun: return "CAPTURE \(target) IN A RUN"
            case .scoreInRun: return "SCORE \(target) IN A RUN"
            case .reachSector: return "REACH SECTOR \(target)"
            case .bouncesToday: return "RICOCHET \(target) BOUNCERS"
            case .closeCallsToday: return "\(target) CLOSE CALLS"
            }
        }
    }

    struct RunStats {
        var score = 0
        var captures = 0
        var perfects = 0
        var longestStreak = 0
        var bounces = 0
        var closeCalls = 0
        var maxLevel = 1
    }

    // Deterministic per calendar day (same key the daily challenge uses).
    static var today: [Mission] {
        var rng = SeededRandom(seed: UInt64(Daily.todayKey) &* 0x5851F42D4C957F2D)
        var kinds = Kind.allCases
        var missions: [Mission] = []
        for index in 0..<3 {
            let pick = Int(rng.next() % UInt64(kinds.count))
            let kind = kinds.remove(at: pick)
            let mission: Mission
            switch kind {
            case .perfectsInRun:
                let target = 3 + Int(rng.next() % 4)          // 3...6
                mission = Mission(index: index, kind: kind, target: target, xp: target * 10)
            case .capturesInRun:
                let target = 12 + Int(rng.next() % 11)        // 12...22
                mission = Mission(index: index, kind: kind, target: target, xp: 25 + target)
            case .scoreInRun:
                let target = 15 + Int(rng.next() % 21)        // 15...35
                mission = Mission(index: index, kind: kind, target: target, xp: 20 + target)
            case .reachSector:
                let target = 3 + Int(rng.next() % 3)          // 3...5
                mission = Mission(index: index, kind: kind, target: target, xp: target * 15)
            case .bouncesToday:
                let target = 3 + Int(rng.next() % 4)          // 3...6
                mission = Mission(index: index, kind: kind, target: target, xp: 30)
            case .closeCallsToday:
                let target = 2 + Int(rng.next() % 3)          // 2...4
                mission = Mission(index: index, kind: kind, target: target, xp: 25)
            }
            missions.append(mission)
        }
        return missions
    }

    private static func progressKey(_ index: Int) -> String { "missions.\(Daily.todayKey).p\(index)" }
    private static func doneKey(_ index: Int) -> String { "missions.\(Daily.todayKey).d\(index)" }

    static func progress(_ mission: Mission) -> Int {
        UserDefaults.standard.integer(forKey: progressKey(mission.index))
    }

    static func isComplete(_ mission: Mission) -> Bool {
        UserDefaults.standard.bool(forKey: doneKey(mission.index))
    }

    private static func value(of mission: Mission, in stats: RunStats) -> Int {
        switch mission.kind {
        case .perfectsInRun: return stats.perfects
        case .capturesInRun: return stats.captures
        case .scoreInRun: return stats.score
        case .reachSector: return stats.maxLevel
        case .bouncesToday: return stats.bounces
        case .closeCallsToday: return stats.closeCalls
        }
    }

    // Folds a finished run in; returns missions completed by THIS run (their XP
    // is applied here) and whether that XP crossed a pilot level.
    static func report(_ stats: RunStats) -> (completed: [Mission], leveledUp: Bool) {
        let defaults = UserDefaults.standard
        var completed: [Mission] = []
        var leveledUp = false
        for mission in today {
            guard !isComplete(mission) else { continue }
            let runValue = value(of: mission, in: stats)
            let stored = progress(mission)
            let progressed = mission.kind.isCumulative ? stored + runValue : max(stored, runValue)
            defaults.set(min(progressed, mission.target), forKey: progressKey(mission.index))
            if progressed >= mission.target {
                defaults.set(true, forKey: doneKey(mission.index))
                if Progress.addXP(mission.xp) { leveledUp = true }
                completed.append(mission)
            }
        }
        return (completed, leveledUp)
    }
}
