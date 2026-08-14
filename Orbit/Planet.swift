import SpriteKit

// Power-up planets appear occasionally in the chain; each changes what a
// capture does (see GameScene.capture) and reads differently at a glance.
enum PlanetKind {
    case normal, golden, shield, magnet, unstable
}

final class Planet: SKNode {
    let ringRadius: CGFloat
    let coreRadius: CGFloat
    let orbitSpeed: CGFloat
    let color: SKColor
    let kind: PlanetKind
    let isGuardian: Bool

    // Unstable planets shrink their ring while orbited; everyone else keeps this fixed.
    private(set) var currentRingRadius: CGFloat

    private let ring: SKShapeNode

    init(ringRadius: CGFloat, coreRadius: CGFloat, orbitSpeed: CGFloat, color: SKColor,
         kind: PlanetKind = .normal, isGuardian: Bool = false) {
        self.ringRadius = ringRadius
        self.coreRadius = coreRadius
        self.orbitSpeed = orbitSpeed
        self.color = color
        self.kind = kind
        self.isGuardian = isGuardian
        self.currentRingRadius = ringRadius
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

        decorate()
        if isGuardian { decorateGuardian() }
    }

    // Guardian planets (every 10th sector): a heavier double ring and a slow
    // menacing core pulse — the gates are added by the scene.
    private func decorateGuardian() {
        let outer = SKShapeNode(circleOfRadius: ringRadius + 14)
        outer.strokeColor = SKColor(red: 1.0, green: 0.35, blue: 0.3, alpha: 0.5)
        outer.lineWidth = 1.5
        outer.glowWidth = 3
        outer.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.3, duration: 0.9),
            .fadeAlpha(to: 1.0, duration: 0.9),
        ])))
        addChild(outer)

        let aura = SKSpriteNode(texture: Textures.softDot)
        aura.size = CGSize(width: coreRadius * 11, height: coreRadius * 11)
        aura.color = SKColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 1)
        aura.colorBlendFactor = 1
        aura.alpha = 0.22
        aura.blendMode = .add
        aura.zPosition = -1
        aura.run(.repeatForever(.sequence([
            .scale(to: 1.15, duration: 1.1),
            .scale(to: 1.0, duration: 1.1),
        ])))
        addChild(aura)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func decorate() {
        switch kind {
        case .normal:
            break
        case .golden:
            let outer = SKShapeNode(circleOfRadius: ringRadius + 9)
            outer.strokeColor = color.withAlphaComponent(0.5)
            outer.lineWidth = 1
            outer.glowWidth = 2
            outer.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.35, duration: 0.7),
                .fadeAlpha(to: 1.0, duration: 0.7),
            ])))
            addChild(outer)
            let sparkle = SKEmitterNode()
            sparkle.particleTexture = Textures.softDot
            sparkle.particleBirthRate = 10
            sparkle.particleLifetime = 0.9
            sparkle.particleAlpha = 0.7
            sparkle.particleAlphaSpeed = -0.8
            sparkle.particleScale = 0.16
            sparkle.particleScaleSpeed = -0.12
            sparkle.particleSpeed = 26
            sparkle.emissionAngleRange = .pi * 2
            sparkle.particlePositionRange = CGVector(dx: coreRadius * 2, dy: coreRadius * 2)
            sparkle.particleBlendMode = .add
            sparkle.particleColor = color
            sparkle.particleColorBlendFactor = 1
            addChild(sparkle)
        case .shield:
            let inner = SKShapeNode(circleOfRadius: ringRadius - 9)
            inner.strokeColor = color.withAlphaComponent(0.45)
            inner.lineWidth = 1
            inner.glowWidth = 1.5
            addChild(inner)
        case .magnet:
            let band = SKShapeNode(circleOfRadius: ringRadius + 12)
            band.strokeColor = color.withAlphaComponent(0.4)
            band.lineWidth = 1
            band.glowWidth = 2
            band.run(.repeatForever(.sequence([
                .group([.scale(to: 1.08, duration: 0.9), .fadeAlpha(to: 0.2, duration: 0.9)]),
                .group([.scale(to: 1.0, duration: 0.0), .fadeAlpha(to: 1.0, duration: 0.0)]),
            ])))
            addChild(band)
        case .unstable:
            ring.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.45, duration: 0.12),
                .fadeAlpha(to: 1.0, duration: 0.16),
            ])))
        }
    }

    // Called every frame while the player orbits an unstable planet.
    func shrinkRing(dt: CGFloat) {
        guard kind == .unstable else { return }
        let floor = coreRadius + 30
        guard currentRingRadius > floor else { return }
        currentRingRadius = max(floor, currentRingRadius - 16 * dt)
        ring.setScale(currentRingRadius / ringRadius)
    }

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
    // A sector hue biases the nebulae so each level's sky reads distinct.
    private var nebulaHue: CGFloat?

    func sprinkleStars(count: Int = 34, nebulaHue: CGFloat? = nil) {
        self.nebulaHue = nebulaHue
        sprinkle(count: count)
    }

    private func sprinkle(count: Int) {
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
            var hue = nebulaHue.map { $0 + CGFloat.random(in: -0.08...0.08) }
                ?? CGFloat.random(in: 0...1)
            hue = hue.truncatingRemainder(dividingBy: 1)
            if hue < 0 { hue += 1 }
            nebula.color = SKColor(hue: hue, saturation: 0.8, brightness: 0.7, alpha: 1)
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
