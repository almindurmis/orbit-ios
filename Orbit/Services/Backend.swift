import Foundation
import FirebaseCore
import FirebaseFirestore

struct LeaderboardEntry: Identifiable {
    let id: String
    let name: String
    let avatar: Int
    let score: Int
}

enum LeaderboardPeriod: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case allTime = "All Time"

    var id: String { rawValue }

    // Period keys use the ISO week/month so everyone lands on the same board.
    var key: String {
        let cal = Calendar(identifier: .iso8601)
        let now = Date()
        switch self {
        case .weekly:
            return String(format: "w-%04d-%02d",
                          cal.component(.yearForWeekOfYear, from: now),
                          cal.component(.weekOfYear, from: now))
        case .monthly:
            return String(format: "m-%04d-%02d",
                          cal.component(.year, from: now),
                          cal.component(.month, from: now))
        case .allTime:
            return "alltime"
        }
    }
}

enum Backend {
    private(set) static var isConfigured = false

    // Firebase only spins up when GoogleService-Info.plist is present, so the game
    // stays fully playable offline before the project is wired up.
    static func configure() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
        isConfigured = true
    }

    static func upsertUser(_ profile: Profile) {
        guard isConfigured else { return }
        Firestore.firestore().collection("users").document(DeviceID.id).setData([
            "name": profile.name,
            "avatar": profile.avatar,
            "updated": FieldValue.serverTimestamp(),
        ], merge: true)
    }

    // Profile edits propagate to existing board entries immediately, so a new
    // name/avatar shows on the leaderboard without waiting for the next score.
    static func updateProfile(_ profile: Profile) {
        guard isConfigured else { return }
        upsertUser(profile)
        let db = Firestore.firestore()
        for period in LeaderboardPeriod.allCases {
            let ref = db.collection("boards").document(period.key)
                .collection("entries").document(DeviceID.id)
            ref.getDocument { snapshot, _ in
                guard snapshot?.exists == true else { return }
                ref.updateData(["name": profile.name, "avatar": profile.avatar])
            }
        }
    }

    // Keeps the best score per period; name/avatar refresh with every submit.
    static func submitScore(_ score: Int) {
        guard isConfigured, score > 0, let profile = ProfileStore.load() else { return }
        let db = Firestore.firestore()
        for period in LeaderboardPeriod.allCases {
            let ref = db.collection("boards").document(period.key)
                .collection("entries").document(DeviceID.id)
            ref.getDocument { snapshot, _ in
                let existing = snapshot?.data()?["score"] as? Int ?? 0
                guard score > existing else { return }
                ref.setData([
                    "name": profile.name,
                    "avatar": profile.avatar,
                    "score": score,
                    "updated": FieldValue.serverTimestamp(),
                ], merge: true)
            }
        }
    }

    // App Store 5.1.1: users who can create an account must be able to delete
    // it in-app. Removes the user doc and current-period board entries.
    static func deleteAccount() {
        guard isConfigured else { return }
        let db = Firestore.firestore()
        db.collection("users").document(DeviceID.id).delete()
        for period in LeaderboardPeriod.allCases {
            db.collection("boards").document(period.key)
                .collection("entries").document(DeviceID.id).delete()
        }
    }

    static func leaderboard(_ period: LeaderboardPeriod) async throws -> [LeaderboardEntry] {
        guard isConfigured else { return [] }
        let snapshot = try await Firestore.firestore()
            .collection("boards").document(period.key).collection("entries")
            .order(by: "score", descending: true)
            .limit(to: 100)
            .getDocuments()
        return snapshot.documents.map { doc in
            let data = doc.data()
            return LeaderboardEntry(id: doc.documentID,
                                    name: data["name"] as? String ?? "…",
                                    avatar: data["avatar"] as? Int ?? 0,
                                    score: data["score"] as? Int ?? 0)
        }
    }
}
