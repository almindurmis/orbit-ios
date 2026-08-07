import SpriteKit
import UIKit

final class GameScene: SKScene {

    private enum State { case menu, orbiting, flying, dead }

    // Tuning
    private let launchSpeed: CGFloat = 640
    private let baseOrbitSpeed: CGFloat = 1.5
    private let maxOrbitSpeed: CGFloat = 3.1
    private let missMargin: CGFloat = 240

    private var state: State = .menu

    private var planets: [Planet] = []
    private var currentIndex = 0
    private var planetCount = 0

    private let player = SKNode()
    private var trail: SKEmitterNode!
    private var aim: SKSpriteNode!

    private var orbitAngle: CGFloat = 0
    private var orbitSpin: CGFloat = 1
    private var orbitSpeed: CGFloat = 1.5

    private var velocity: CGPoint = .zero
    private var launchOrigin: CGPoint = .zero
    private var launchDir: CGPoint = .zero
    private var prevTargetDistance: CGFloat = 0

    private var score = 0 { didSet { scoreLabel.text = "\(score)" } }
    private var best = UserDefaults.standard.integer(forKey: "bestScore")

    private var lastUpdate: TimeInterval = 0
    private var gameOverReady = false

    // HUD
    private let cam = SKCameraNode()
    private let scoreLabel = SKLabelNode(fontNamed: "HelveticaNeue-UltraLight")
    private let menuLayer = SKNode()
    private let gameOverLayer = SKNode()
    private let titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-UltraLight")
    private let menuBestLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let menuTapLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let dimNode = SKSpriteNode(color: SKColor(white: 0, alpha: 0.5), size: .zero)
    private let overCaptionLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let finalScoreLabel = SKLabelNode(fontNamed: "HelveticaNeue-UltraLight")
    private let finalBestLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let overTapLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = Palette.background
        setupPlayer()
        buildHUD()
        startRun(showMenu: true)
    }

    private func setupPlayer() {
        let halo = SKSpriteNode(texture: Textures.softDot)
        halo.size = CGSize(width: 44, height: 44)
        halo.blendMode = .add
        halo.alpha = 0.9
        player.addChild(halo)

        let core = SKShapeNode(circleOfRadius: 6)
        core.fillColor = .white
        core.strokeColor = .clear
        player.addChild(core)

        trail = SKEmitterNode()
        trail.particleTexture = Textures.softDot
        trail.particleBirthRate = 0
        trail.particleLifetime = 0.45
        trail.particleAlpha = 0.5
        trail.particleAlphaSpeed = -1.2
        trail.particleScale = 0.35
        trail.particleScaleSpeed = -0.7
        trail.particleBlendMode = .add
        trail.particleColor = .white
        trail.particleColorBlendFactor = 1
        trail.targetNode = self
        trail.zPosition = -1
        player.addChild(trail)

        aim = SKSpriteNode(texture: Textures.fadingLine(length: 64, thickness: 2))
        aim.anchorPoint = CGPoint(x: 0, y: 0.5)
        aim.alpha = 0.3
        player.addChild(aim)

        player.zPosition = 10
        addChild(player)
    }

    private func buildHUD() {
        camera = cam
        addChild(cam)

        scoreLabel.fontSize = 64
        scoreLabel.fontColor = Palette.textPrimary
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.text = "0"
        cam.addChild(scoreLabel)

        menuLayer.zPosition = 100
        cam.addChild(menuLayer)

        titleLabel.text = "O R B I T"
        titleLabel.fontSize = 64
        titleLabel.fontColor = Palette.textPrimary
        menuLayer.addChild(titleLabel)

        menuBestLabel.fontSize = 15
        menuBestLabel.fontColor = Palette.textDim
        menuLayer.addChild(menuBestLabel)

        menuTapLabel.text = "TAP TO PLAY"
        menuTapLabel.fontSize = 17
        menuTapLabel.fontColor = Palette.textDim
        menuTapLabel.run(pulseForever())
        menuLayer.addChild(menuTapLabel)

        gameOverLayer.zPosition = 100
        gameOverLayer.isHidden = true
        cam.addChild(gameOverLayer)

        gameOverLayer.addChild(dimNode)

        overCaptionLabel.text = "SCORE"
        overCaptionLabel.fontSize = 16
        overCaptionLabel.fontColor = Palette.textDim
        gameOverLayer.addChild(overCaptionLabel)

        finalScoreLabel.fontSize = 96
        finalScoreLabel.fontColor = Palette.textPrimary
        finalScoreLabel.verticalAlignmentMode = .center
        gameOverLayer.addChild(finalScoreLabel)

        finalBestLabel.fontSize = 17
        finalBestLabel.fontColor = Palette.textDim
        gameOverLayer.addChild(finalBestLabel)

        overTapLabel.text = "TAP TO RETRY"
        overTapLabel.fontSize = 17
        overTapLabel.fontColor = Palette.textDim
        overTapLabel.run(pulseForever())
        gameOverLayer.addChild(overTapLabel)

        layoutHUD()
    }

    private func pulseForever() -> SKAction {
        .repeatForever(.sequence([.fadeAlpha(to: 0.25, duration: 0.9),
                                  .fadeAlpha(to: 1.0, duration: 0.9)]))
    }

    private func layoutHUD() {
        let h = size.height
        scoreLabel.position = CGPoint(x: 0, y: h / 2 - 64)

        titleLabel.position = CGPoint(x: 0, y: h * 0.24)
        menuBestLabel.position = CGPoint(x: 0, y: h * 0.24 - 44)
        menuTapLabel.position = CGPoint(x: 0, y: -h * 0.30)

        dimNode.size = CGSize(width: size.width, height: h)
        overCaptionLabel.position = CGPoint(x: 0, y: 96)
        finalScoreLabel.position = CGPoint(x: 0, y: 20)
        finalBestLabel.position = CGPoint(x: 0, y: -56)
        overTapLabel.position = CGPoint(x: 0, y: -h * 0.30)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard cam.parent != nil else { return }
        layoutHUD()
    }

    // MARK: - Run lifecycle

    private func startRun(showMenu: Bool) {
        for planet in planets { planet.removeFromParent() }
        planets.removeAll()
        planetCount = 0
        currentIndex = 0
        score = 0

        let first = makePlanet(ringRadius: 90, at: .zero)
        addChild(first)
        planets.append(first)
        spawnNext()

        orbitAngle = -.pi / 2
        orbitSpin = 1
        orbitSpeed = first.orbitSpeed
        player.position = first.position + .polar(angle: orbitAngle, radius: first.ringRadius)
        player.alpha = 1
        trail.particleBirthRate = 45
        aim.isHidden = false

        cam.position = camTarget()

        state = showMenu ? .menu : .orbiting
        menuLayer.isHidden = !showMenu
        gameOverLayer.isHidden = true
        scoreLabel.isHidden = showMenu
        menuBestLabel.text = "BEST \(best)"
        menuBestLabel.isHidden = best == 0
    }

    private func makePlanet(ringRadius: CGFloat, at position: CGPoint) -> Planet {
        let speed = min(baseOrbitSpeed + CGFloat(planetCount) * 0.045, maxOrbitSpeed)
        let planet = Planet(ringRadius: ringRadius,
                            coreRadius: CGFloat.random(in: 10...16),
                            orbitSpeed: speed,
                            color: Palette.planetColor(index: planetCount))
        planet.position = position
        planet.sprinkleStars()
        planetCount += 1
        return planet
    }

    private func spawnNext() {
        guard let last = planets.last else { return }
        let distance = CGFloat.random(in: 270...420)
        let spread: CGFloat = .pi * 0.36
        let angle = CGFloat.pi / 2 + CGFloat.random(in: -spread...spread)
        let planet = makePlanet(ringRadius: CGFloat.random(in: 62...105),
                                at: last.position + .polar(angle: angle, radius: distance))
        addChild(planet)
        planets.append(planet)
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat = lastUpdate == 0 ? 1.0 / 60.0 : CGFloat(min(currentTime - lastUpdate, 1.0 / 30.0))
        lastUpdate = currentTime

        switch state {
        case .menu, .orbiting:
            let planet = planets[currentIndex]
            orbitAngle += orbitSpin * orbitSpeed * dt
            player.position = planet.position + .polar(angle: orbitAngle, radius: planet.ringRadius)
            let tangent = tangentDirection()
            aim.zRotation = atan2(tangent.y, tangent.x)
        case .flying:
            player.position = player.position + velocity * dt
            let target = planets[currentIndex + 1]
            let d = player.position.distance(to: target.position)
            if d <= target.ringRadius && prevTargetDistance > target.ringRadius {
                capture(target)
            } else if d > prevTargetDistance && d > target.ringRadius + missMargin {
                die()
            } else {
                prevTargetDistance = d
            }
        case .dead:
            break
        }

        let goal = camTarget()
        let k = 1 - exp(-5 * dt)
        cam.position = CGPoint(x: cam.position.x + (goal.x - cam.position.x) * k,
                               y: cam.position.y + (goal.y - cam.position.y) * k)
    }

    private func camTarget() -> CGPoint {
        switch state {
        case .flying:
            let target = planets[currentIndex + 1]
            return (player.position + target.position) * 0.5
        default:
            guard planets.count > currentIndex + 1 else { return planets[currentIndex].position }
            let current = planets[currentIndex].position
            let next = planets[currentIndex + 1].position
            return current * 0.62 + next * 0.38
        }
    }

    private func tangentDirection() -> CGPoint {
        let planet = planets[currentIndex]
        let radial = (player.position - planet.position).normalized
        return CGPoint(x: -radial.y * orbitSpin, y: radial.x * orbitSpin)
    }

    // MARK: - Actions

    private func launch() {
        let dir = tangentDirection()
        velocity = dir * launchSpeed
        launchOrigin = player.position
        launchDir = dir
        prevTargetDistance = player.position.distance(to: planets[currentIndex + 1].position)
        trail.particleBirthRate = 150
        aim.isHidden = true
        state = .flying
        Haptics.tap()
    }

    private func capture(_ target: Planet) {
        // Impact parameter: perpendicular distance of the flight line from the planet core.
        let impact = abs(cross(launchDir, target.position - launchOrigin))
        let perfect = impact <= target.coreRadius + 6

        currentIndex += 1
        let radial = player.position - target.position
        orbitAngle = atan2(radial.y, radial.x)
        orbitSpin = cross(radial, velocity) >= 0 ? 1 : -1
        orbitSpeed = target.orbitSpeed
        player.position = target.position + .polar(angle: orbitAngle, radius: target.ringRadius)

        score += perfect ? 2 : 1
        popup(text: perfect ? "PERFECT +2" : "+1",
              color: perfect ? Palette.gold : Palette.textDim,
              above: target)

        target.pulse()
        if perfect { Haptics.perfect() } else { Haptics.capture() }

        trail.particleBirthRate = 45
        aim.isHidden = false
        state = .orbiting

        spawnNext()
        if planets.count > 5 {
            planets.removeFirst().removeFromParent()
            currentIndex -= 1
        }
    }

    private func popup(text: String, color: SKColor, above planet: Planet) {
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
        label.text = text
        label.fontSize = 22
        label.fontColor = color
        label.position = planet.position + CGPoint(x: 0, y: planet.ringRadius + 22)
        label.zPosition = 20
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 46, duration: 0.7),
                    .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.35)])]),
            .removeFromParent()
        ]))
    }

    private func die() {
        state = .dead
        trail.particleBirthRate = 0
        aim.isHidden = true
        player.alpha = 0
        Haptics.death()

        let burst = SKEmitterNode()
        burst.particleTexture = Textures.softDot
        burst.particleBirthRate = 900
        burst.numParticlesToEmit = 42
        burst.particleLifetime = 0.7
        burst.particleSpeed = 190
        burst.particleSpeedRange = 120
        burst.emissionAngleRange = .pi * 2
        burst.particleAlpha = 0.8
        burst.particleAlphaSpeed = -1.2
        burst.particleScale = 0.4
        burst.particleScaleSpeed = -0.5
        burst.particleBlendMode = .add
        burst.position = player.position
        burst.zPosition = 15
        addChild(burst)
        burst.run(.sequence([.wait(forDuration: 1.5), .removeFromParent()]))

        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: "bestScore")
        }

        gameOverReady = false
        run(.sequence([.wait(forDuration: 0.55),
                       .run { [weak self] in self?.showGameOver() }]))
    }

    private func showGameOver() {
        finalScoreLabel.text = "\(score)"
        finalBestLabel.text = "BEST \(best)"
        scoreLabel.isHidden = true
        gameOverLayer.alpha = 0
        gameOverLayer.isHidden = false
        gameOverLayer.run(.fadeIn(withDuration: 0.25))
        gameOverReady = true
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch state {
        case .menu:
            menuLayer.isHidden = true
            scoreLabel.isHidden = false
            state = .orbiting
            Haptics.tap()
        case .orbiting:
            launch()
        case .flying:
            break
        case .dead:
            guard gameOverReady else { return }
            startRun(showMenu: false)
        }
    }
}
