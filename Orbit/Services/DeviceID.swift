import UIKit

// Stable per-device identity: one account per device, no email/password.
enum DeviceID {
    static let id: String = {
        let key = "device.id"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let fresh = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }()
}
