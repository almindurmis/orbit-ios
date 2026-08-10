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

    // MARK: - Paginated leaderboard
    // The board is never downloaded whole: rank comes from server-side count
    // aggregations and rows are fetched in cursor pages, so cost stays flat
    // no matter how many players exist.

    private static func entriesRef(_ period: LeaderboardPeriod) -> CollectionReference {
        Firestore.firestore().collection("boards").document(period.key).collection("entries")
    }

    private static func ordered(_ period: LeaderboardPeriod) -> Query {
        entriesRef(period).order(by: "score", descending: true)
    }

    static func entry(from doc: DocumentSnapshot) -> LeaderboardEntry {
        let data = doc.data() ?? [:]
        return LeaderboardEntry(id: doc.documentID,
                                name: data["name"] as? String ?? "…",
                                avatar: data["avatar"] as? Int ?? 0,
                                score: data["score"] as? Int ?? 0)
    }

    static func myEntryDocument(_ period: LeaderboardPeriod) async throws -> DocumentSnapshot? {
        guard isConfigured else { return nil }
        let doc = try await entriesRef(period).document(DeviceID.id).getDocument()
        return doc.exists ? doc : nil
    }

    // Firestore breaks score ties by document ID descending (implicit __name__
    // key follows the last sort direction), so "ahead of me" = higher score,
    // or same score with a higher document ID.
    static func rank(of doc: DocumentSnapshot, in period: LeaderboardPeriod) async throws -> Int {
        let score = doc.data()?["score"] as? Int ?? 0
        let ref = entriesRef(period)
        let above = try await ref.whereField("score", isGreaterThan: score)
            .count.getAggregation(source: .server).count.intValue
        let tiesAhead = try await ref.whereField("score", isEqualTo: score)
            .whereField(FieldPath.documentID(), isGreaterThan: doc.documentID)
            .count.getAggregation(source: .server).count.intValue
        return above + tiesAhead + 1
    }

    static func page(_ period: LeaderboardPeriod, after doc: DocumentSnapshot?,
                     limit: Int) async throws -> [DocumentSnapshot] {
        guard isConfigured else { return [] }
        var query = ordered(period).limit(to: limit)
        if let doc { query = query.start(afterDocument: doc) }
        return try await query.getDocuments().documents
    }

    static func page(_ period: LeaderboardPeriod, endingBefore doc: DocumentSnapshot,
                     limit: Int) async throws -> [DocumentSnapshot] {
        guard isConfigured else { return [] }
        return try await ordered(period)
            .end(beforeDocument: doc)
            .limit(toLast: limit)
            .getDocuments().documents
    }

    static func page(_ period: LeaderboardPeriod, startingAt doc: DocumentSnapshot,
                     limit: Int) async throws -> [DocumentSnapshot] {
        guard isConfigured else { return [] }
        return try await ordered(period)
            .start(atDocument: doc)
            .limit(to: limit)
            .getDocuments().documents
    }
}
