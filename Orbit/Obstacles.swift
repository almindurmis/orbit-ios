import SpriteKit

// Obstacles live as CHILDREN of the planet they guard (the flight target), so
// they scroll and get culled with it. All collision is manual distance math in
// GameScene's flight update — same style as capture/miss detection.

// A jut of glowing rock crossing part of the corridor between two planets.
// Flying into a rock is death (Shield saves you); grazing one pays CLOSE CALL.
final class AsteroidWall: SKNode {
    struct Rock {
        let offset: CGPoint   // local to the wall node
        let radius: CGFloat
    }

    let rocks: [Rock]

    init(rocks: [Rock], hue: CGFloat) {
        self.rocks = rocks
        super.init()
        zPosition = 4
        let edge = SKColor(hue: hue, saturation: 0.5, brightness: 1.0, alpha: 1)
        for rock in rocks {
            if let texture = Textures.asteroids.randomElement() {
                let sprite = SKSpriteNode(texture: texture)
                let side = rock.radius * 2.3
                sprite.size = CGSize(width: side, height: side)
                sprite.position = rock.offset
                sprite.zRotation = CGFloat.random(in: 0...(2 * .pi))
                addChild(sprite)
            }
            let glow = SKShapeNode(circleOfRadius: rock.radius + 1)
            glow.strokeColor = edge.withAlphaComponent(0.35)
            glow.lineWidth = 1
            glow.glowWidth = 2.5
            glow.fillColor = .clear
            glow.position = rock.offset
            addChild(glow)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// A springy neon orb: hitting it reflects the flight instead of ending it —
// bank shots around walls are the intended skill play.
final class Bouncer: SKNode {
    static let radius: CGFloat = 16

    private let shell: SKShapeNode

    override init() {
        shell = SKShapeNode(circleOfRadius: Bouncer.radius)
        super.init()
        zPosition = 4

        let halo = SKSpriteNode(texture: Textures.softDot)
        halo.size = CGSize(width: Bouncer.radius * 5, height: Bouncer.radius * 5)
        halo.color = Palette.bouncerPink
        halo.colorBlendFactor = 1
        halo.alpha = 0.3
        halo.blendMode = .add
        halo.zPosition = -1
        addChild(halo)

        shell.strokeColor = Palette.bouncerPink
        shell.lineWidth = 2.5
        shell.glowWidth = 3
        shell.fillColor = Palette.bouncerPink.withAlphaComponent(0.15)
        addChild(shell)

        let core = SKShapeNode(circleOfRadius: 4.5)
        core.fillColor = Palette.bouncerPink
        core.strokeColor = .clear
        addChild(core)

        shell.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.7),
            .scale(to: 1.0, duration: 0.7),
        ])))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func squash() {
        removeAction(forKey: "squash")
        run(.sequence([
            .scale(to: 0.72, duration: 0.05),
            .scale(to: 1.15, duration: 0.09),
            .scale(to: 1.0, duration: 0.12),
        ]), withKey: "squash")
    }
}

// A shield arc orbiting a planet outside its capture ring: you pass through the
// gap or you don't pass at all. The node's zRotation IS the arc's live center
// angle (driven by a rotate action), so blocking checks read it directly.
final class RotatingGate: SKNode {
    let orbitRadius: CGFloat
    let halfArc: CGFloat
    static let bandHalfWidth: CGFloat = 12

    init(orbitRadius: CGFloat, halfArc: CGFloat, angularSpeed: CGFloat, color: SKColor) {
        self.orbitRadius = orbitRadius
        self.halfArc = halfArc
        super.init()
        zPosition = 3

        let path = CGMutablePath()
        path.addArc(center: .zero, radius: orbitRadius,
                    startAngle: -halfArc, endAngle: halfArc, clockwise: false)
        let arc = SKShapeNode(path: path)
        arc.strokeColor = color.withAlphaComponent(0.9)
        arc.lineWidth = 4.5
        arc.lineCap = .round
        arc.glowWidth = 4
        arc.fillColor = .clear
        addChild(arc)

        for sign: CGFloat in [-1, 1] {
            let cap = SKShapeNode(circleOfRadius: 4)
            cap.fillColor = color
            cap.strokeColor = .clear
            cap.glowWidth = 3
            cap.position = .polar(angle: sign * halfArc, radius: orbitRadius)
            addChild(cap)
        }

        let duration = TimeInterval(2 * .pi / abs(angularSpeed))
        run(.repeatForever(.rotate(byAngle: angularSpeed > 0 ? 2 * .pi : -2 * .pi,
                                   duration: duration)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Whether the arc currently covers the given angle (in the planet's frame).
    func isBlocking(angle: CGFloat) -> Bool {
        var diff = (angle - zRotation).truncatingRemainder(dividingBy: 2 * .pi)
        if diff > .pi { diff -= 2 * .pi }
        if diff < -.pi { diff += 2 * .pi }
        return abs(diff) <= halfArc + 0.04
    }
}
