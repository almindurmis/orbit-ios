import SpriteKit

final class Planet: SKNode {
    let ringRadius: CGFloat
    let coreRadius: CGFloat
    let orbitSpeed: CGFloat
    let color: SKColor

    private let ring: SKShapeNode

    init(ringRadius: CGFloat, coreRadius: CGFloat, orbitSpeed: CGFloat, color: SKColor) {
        self.ringRadius = ringRadius
        self.coreRadius = coreRadius
        self.orbitSpeed = orbitSpeed
        self.color = color
        self.ring = SKShapeNode(circleOfRadius: ringRadius)
        super.init()

        let halo = SKSpriteNode(texture: Textures.softDot)
        halo.size = CGSize(width: coreRadius * 7, height: coreRadius * 7)
        halo.color = color
        halo.colorBlendFactor = 1
        halo.alpha = 0.35
        halo.blendMode = .add
        halo.zPosition = -1
        addChild(halo)

        let core = SKShapeNode(circleOfRadius: coreRadius)
        core.fillColor = color
        core.strokeColor = .clear
        addChild(core)

        ring.strokeColor = color.withAlphaComponent(0.85)
        ring.lineWidth = 2
        ring.glowWidth = 3
        ring.fillColor = .clear
        addChild(ring)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func pulse() {
        ring.removeAllActions()
        ring.setScale(1)
        let up = SKAction.scale(to: 1.18, duration: 0.09)
        up.timingMode = .easeOut
        let down = SKAction.scale(to: 1, duration: 0.22)
        down.timingMode = .easeOut
        ring.run(.sequence([up, down]))
    }

    // Backdrop lives as children so it scrolls and gets culled with its planet.
    func sprinkleStars(count: Int = 34) {
        let tints: [SKColor] = [
            .white, .white,
            SKColor(red: 0.72, green: 0.85, blue: 1.0, alpha: 1),
            SKColor(red: 1.0, green: 0.9, blue: 0.78, alpha: 1),
            SKColor(red: 0.85, green: 0.8, blue: 1.0, alpha: 1),
        ]
        for i in 0..<count {
            let r = CGFloat.random(in: (ringRadius + 40)...560)
            let a = CGFloat.random(in: 0...(2 * .pi))
            let position = CGPoint(x: cos(a) * r, y: sin(a) * r)
            let tint = tints.randomElement() ?? .white

            // A few bright stars get a soft glow halo; the rest are pinpricks.
            if i < 6 {
                let glow = SKSpriteNode(texture: Textures.softDot)
                glow.size = CGSize(width: CGFloat.random(in: 10...20), height: CGFloat.random(in: 10...20))
                glow.color = tint
                glow.colorBlendFactor = 1
                glow.blendMode = .add
                glow.alpha = CGFloat.random(in: 0.5...0.8)
                glow.position = position
                glow.zPosition = -20
                glow.run(twinkle(base: glow.alpha, floor: 0.25))
                addChild(glow)
            }

            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.6...2.1))
            star.fillColor = tint
            star.strokeColor = .clear
            star.position = position
            let baseAlpha = CGFloat.random(in: 0.15...0.65)
            star.alpha = baseAlpha
            star.zPosition = -20
            star.run(twinkle(base: baseAlpha, floor: 0.06))
            addChild(star)
        }
        addNebulae()
    }

    private func twinkle(base: CGFloat, floor: CGFloat) -> SKAction {
        .repeatForever(.sequence([
            .fadeAlpha(to: floor, duration: TimeInterval.random(in: 0.8...2.4)),
            .fadeAlpha(to: base, duration: TimeInterval.random(in: 0.8...2.4)),
        ]))
    }

    // Large, very faint additive color washes — reads as distant nebulae.
    private func addNebulae() {
        for _ in 0..<(Int.random(in: 1...2)) {
            let nebula = SKSpriteNode(texture: Textures.softDot)
            let diameter = CGFloat.random(in: 480...850)
            nebula.size = CGSize(width: diameter, height: diameter * CGFloat.random(in: 0.6...1.0))
            nebula.color = SKColor(hue: CGFloat.random(in: 0...1), saturation: 0.8,
                                   brightness: 0.7, alpha: 1)
            nebula.colorBlendFactor = 1
            nebula.blendMode = .add
            nebula.alpha = CGFloat.random(in: 0.05...0.10)
            nebula.zRotation = CGFloat.random(in: 0...(2 * .pi))
            let r = CGFloat.random(in: 120...420)
            let a = CGFloat.random(in: 0...(2 * .pi))
            nebula.position = CGPoint(x: cos(a) * r, y: sin(a) * r)
            nebula.zPosition = -26
            addChild(nebula)
        }
    }
}
