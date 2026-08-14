import Foundation

// Local run log feeding the pilot stats screen. Free shows the recent slice;
// Premium reads the whole history.
struct RunRecord: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let mode: String          // classic / daily / gauntlet / custom
    let score: Int
    let captures: Int
    let perfects: Int
    let longestStreak: Int
    let maxSector: Int
    let deathCause: String    // drift / wall / gate
    let duration: Double
}

enum RunHistory {
    private static let key = "runs.history"
    private static let cap = 300

    static func all() -> [RunRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([RunRecord].self, from: data)
        else { return [] }
        return records
    }

    /// A revive undoes the just-logged death; the final death re-logs the run.
    static func dropLast() {
        var records = all()
        guard !records.isEmpty else { return }
        records.removeLast()
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func save(_ record: RunRecord) {
        var records = all()
        records.append(record)
        if records.count > cap { records.removeFirst(records.count - cap) }
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
