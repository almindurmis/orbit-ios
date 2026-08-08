import SwiftUI
import SpriteKit

// Shared backdrop for the Leaderboard and Profile sheets: a lighter galactic
// gradient with nebula glows, plus a transparent SpriteKit layer of twinkling
// stars and slow asteroid/comet flybys so the screens feel alive.
struct GalaxyBackground: View {
    @State private var scene: BackdropScene = {
        let scene = BackdropScene(size: CGSize(width: 390, height: 800))
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.07, green: 0.08, blue: 0.20),
                Color(red: 0.11, green: 0.08, blue: 0.26),
                Color(red: 0.04, green: 0.05, blue: 0.13),
            ], startPoint: .top, endPoint: .bottom)

            RadialGradient(colors: [Color(red: 0.45, green: 0.30, blue: 0.90).opacity(0.28), .clear],
                           center: UnitPoint(x: 0.85, y: 0.12), startRadius: 0, endRadius: 340)
            RadialGradient(colors: [Color(red: 0.20, green: 0.70, blue: 0.90).opacity(0.20), .clear],
                           center: UnitPoint(x: 0.10, y: 0.78), startRadius: 0, endRadius: 320)

            SpriteView(scene: scene, options: [.allowsTransparency])
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private final class BackdropScene: SKScene {
    private var populated = false

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        populateIfNeeded()
        run(.repeatForever(.sequence([
            .wait(forDuration: 6, withRange: 5),
            .run { [weak self] in self?.spawnFlyby() },
        ])))
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        populateIfNeeded()
    }

    private func populateIfNeeded() {
        guard !populated, size.width > 50 else { return }
        populated = true
        let tints: [SKColor] = [.white, .white,
                                SKColor(red: 0.72, green: 0.85, blue: 1.0, alpha: 1),
                                SKColor(red: 1.0, green: 0.9, blue: 0.78, alpha: 1)]
        for i in 0..<70 {
            let position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                   y: CGFloat.random(in: 0...size.height))
            let tint = tints.randomElement() ?? .white
            if i < 8 {
                let glow = SKSpriteNode(texture: Textures.softDot)
                let d = CGFloat.random(in: 8...16)
                glow.size = CGSize(width: d, height: d)
                glow.color = tint
                glow.colorBlendFactor = 1
                glow.blendMode = .add
                glow.alpha = CGFloat.random(in: 0.4...0.7)
                glow.position = position
                glow.run(twinkle(base: glow.alpha, floor: 0.2))
                addChild(glow)
            }
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.6...1.8))
            star.fillColor = tint
            star.strokeColor = .clear
            star.position = position
            let baseAlpha = CGFloat.random(in: 0.2...0.7)
            star.alpha = baseAlpha
            star.run(twinkle(base: baseAlpha, floor: 0.08))
            addChild(star)
        }
    }

    private func twinkle(base: CGFloat, floor: CGFloat) -> SKAction {
        .repeatForever(.sequence([
            .fadeAlpha(to: floor, duration: TimeInterval.random(in: 0.8...2.4)),
            .fadeAlpha(to: base, duration: TimeInterval.random(in: 0.8...2.4)),
        ]))
    }

    private func spawnFlyby() {
        Bool.random() ? spawnAsteroid() : spawnComet()
    }

    private func course(margin: CGFloat) -> (CGPoint, CGVector) {
        let fromLeft = Bool.random()
        let start = CGPoint(x: fromLeft ? -margin : size.width + margin,
                            y: CGFloat.random(in: 0...size.height))
        let delta = CGVector(dx: (fromLeft ? 1 : -1) * (size.width + margin * 2),
                             dy: CGFloat.random(in: -120...120))
        return (start, delta)
    }

    private func spawnAsteroid() {
        guard let texture = Textures.asteroids.randomElement() else { return }
        let (start, delta) = course(margin: 60)
        let asteroid = SKSpriteNode(texture: texture)
        asteroid.setScale(CGFloat.random(in: 0.3...0.7))
        asteroid.alpha = 0.8
        asteroid.position = start
        addChild(asteroid)
        let duration = TimeInterval.random(in: 9...14)
        asteroid.run(.group([
            .move(by: delta, duration: duration),
            .rotate(byAngle: CGFloat.random(in: -3...3), duration: duration),
        ]))
        asteroid.run(.sequence([.wait(forDuration: duration), .removeFromParent()]))
    }

    private func spawnComet() {
        let (start, delta) = course(margin: 80)
        let comet = SKNode()
        comet.position = start
        let halo = SKSpriteNode(texture: Textures.softDot)
        halo.size = CGSize(width: 20, height: 20)
        halo.color = SKColor(red: 0.75, green: 0.95, blue: 1, alpha: 1)
        halo.colorBlendFactor = 1
        halo.blendMode = .add
        comet.addChild(halo)
        let trail = SKEmitterNode()
        trail.particleTexture = Textures.softDot
        trail.particleBirthRate = 70
        trail.particleLifetime = 1.0
        trail.particleAlpha = 0.4
        trail.particleAlphaSpeed = -0.4
        trail.particleScale = 0.24
        trail.particleScaleSpeed = -0.2
        trail.particleBlendMode = .add
        trail.particleColor = SKColor(red: 0.6, green: 0.9, blue: 1, alpha: 1)
        trail.particleColorBlendFactor = 1
        trail.targetNode = self
        comet.addChild(trail)
        addChild(comet)
        comet.run(.sequence([
            .move(by: delta, duration: TimeInterval.random(in: 4...7)),
            .removeFromParent(),
        ]))
    }
}
