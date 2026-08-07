import SwiftUI

@main
struct OrbitApp: App {
    init() {
        Backend.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
