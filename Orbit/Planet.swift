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

    // Stars live as children so they scroll and get culled with their planet.
    func sprinkleStars(count: Int = 18) {
        for _ in 0..<count {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.7...1.9))
            star.fillColor = SKColor.white
            star.strokeColor = .clear
            let r = CGFloat.random(in: (ringRadius + 40)...520)
            let a = CGFloat.random(in: 0...(2 * .pi))
            star.position = CGPoint(x: cos(a) * r, y: sin(a) * r)
            let baseAlpha = CGFloat.random(in: 0.15...0.6)
            star.alpha = baseAlpha
            star.zPosition = -20
            let dim = SKAction.fadeAlpha(to: 0.06, duration: TimeInterval.random(in: 0.8...2.4))
            let brighten = SKAction.fadeAlpha(to: baseAlpha, duration: TimeInterval.random(in: 0.8...2.4))
            star.run(.repeatForever(.sequence([dim, brighten])))
            addChild(star)
        }
    }
}
