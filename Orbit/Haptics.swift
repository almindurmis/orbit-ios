import UIKit

enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static func tap() { light.impactOccurred() }
    static func capture() { rigid.impactOccurred(intensity: 0.8) }
    static func perfect() { notification.notificationOccurred(.success) }
    static func death() { notification.notificationOccurred(.error) }
}
