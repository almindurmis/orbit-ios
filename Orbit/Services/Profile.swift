import Foundation

struct Profile: Codable, Equatable {
    var name: String
    var avatar: Int
}

enum ProfileStore {
    private static let key = "profile"

    static func load() -> Profile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Profile.self, from: data)
    }

    static func save(_ profile: Profile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
