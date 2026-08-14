import Foundation
import FirebaseFirestore

// Ghost racing for the daily challenge. Everyone flies the same seeded world,
// so a ghost is just position samples over time — recorded at ~8 Hz, a few KB.
// Your best run's ghost is kept locally and rides along with your daily-board
// entry; opponents' ghosts are fetched from the top of today's board.
struct GhostRun {
    let name: String
    let samples: [Double]   // flat [t0, x0, y0, t1, x1, y1, …]
    let isMine: Bool
}

enum Ghosts {
    static let sampleInterval = 0.125
    static let maxSamples = 1500          // ~3 minutes of flight

    private static var dayKey: String { "ghost.\(Daily.todayKey)" }
    private static var dayScoreKey: String { "ghost.score.\(Daily.todayKey)" }

    // MARK: - Local best

    static func saveLocalIfBest(samples: [Double], score: Int) {
        let defaults = UserDefaults.standard
        guard score > defaults.integer(forKey: dayScoreKey) else { return }
        defaults.set(score, forKey: dayScoreKey)
        defaults.set(samples.map { ($0 * 10).rounded() / 10 }, forKey: dayKey)
    }

    static func loadLocal() -> [Double]? {
        guard let samples = UserDefaults.standard.array(forKey: dayKey) as? [Double],
              samples.count >= 6 else { return nil }
        return samples
    }

    // MARK: - Today's board (score + ghost, best per player)

    private static var todayBoardKey: String {
        let key = Daily.todayKey
        return String(format: "d-%04d-%02d-%02d", key / 10000, (key / 100) % 100, key % 100)
    }

    private static var entries: CollectionReference {
        Firestore.firestore().collection("boards").document(todayBoardKey).collection("entries")
    }

    static func submitDaily(score: Int, ghost: [Double]) {
        guard Backend.isConfigured, score > 0, let profile = ProfileStore.load() else { return }
        let ref = entries.document(DeviceID.id)
        let rounded = ghost.map { ($0 * 10).rounded() / 10 }
        ref.getDocument { snapshot, _ in
            let existing = snapshot?.data()?["score"] as? Int ?? 0
            guard score > existing else { return }
            ref.setData([
                "name": profile.name,
                "avatar": profile.avatar,
                "score": score,
                "premium": Premium.isActiveNow,
                "ghost": rounded,
                "updated": FieldValue.serverTimestamp(),
            ], merge: true)
        }
    }

    /// Today's best runs (excluding this device), strongest first.
    static func fetchTopGhosts(limit: Int) async -> [GhostRun] {
        guard Backend.isConfigured else { return [] }
        let docs = (try? await entries.order(by: "score", descending: true)
            .limit(to: limit + 1).getDocuments().documents) ?? []
        return docs.compactMap { doc in
            guard doc.documentID != DeviceID.id,
                  let samples = doc.data()["ghost"] as? [Double], samples.count >= 6
            else { return nil }
            let name = doc.data()["name"] as? String ?? "PILOT"
            return GhostRun(name: name, samples: samples, isMine: false)
        }
        .prefix(limit).map { $0 }
    }
}
