import SwiftUI
import SpriteKit

@main
struct OrbitApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
        }
    }
}

struct GameView: View {
    @State private var scene: GameScene = {
        // Placeholder size; .resizeFill adopts the real view size via didChangeSize.
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 120)
            .ignoresSafeArea()
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
    }
}
