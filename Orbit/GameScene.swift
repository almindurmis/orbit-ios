import SpriteKit
import UIKit

final class GameScene: SKScene {

    private enum State { case menu, orbiting, flying, dead }
    private enum Mode { case classic, daily }

    // Tuning
    private let launchSpeed: CGFloat = 640
    private let baseOrbitSpeed: CGFloat = 1.5
    private let maxOrbitSpeed: CGFloat = 3.1
    private let missMargin: CGFloat = 240

    weak var bridge: GameBridge?

    private var state: State = .menu {
        didSet { bridge?.inMenu = state == .menu }
    }
    private var mode: Mode = .classic
    private var rng = SeededRandom(seed: 0)

    private var planets: [Planet] = []
    private var currentIndex = 0
    private var planetCount = 0
    private var captured = 0
    private var lastLevel = 1

    // Infinite levels: one level per 20 captures, rings shrink toward a floor.
    private var level: Int { captured / 20 + 1 }

    private func ringRadiusRange(for level: Int) -> ClosedRange<CGFloat> {
        let t = min(CGFloat(level - 1) / 4.0, 1.0)
        let lower = 95 - (95 - 55) * t
        let upper = 120 - (120 - 75) * t
        return lower...upper
    }

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
    private let titleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let menuBestLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let menuTapLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let dimNode = SKSpriteNode(color: SKColor(white: 0, alpha: 0.5), size: .zero)
    private let overCaptionLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let finalScoreLabel = SKLabelNode(fontNamed: "HelveticaNeue-UltraLight")
    private let finalBestLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let overTapLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let dailyTag = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let levelLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private var dailyButton: SKShapeNode!
    private let dailyTitleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let dailySubLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let overStreakLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let menuButtonLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = Palette.background
        setupPlayer()
        buildHUD()
        setupSpaceDust()
        startAmbientEvents()
        startRun(showMenu: true)
    }

    private func setupSpaceDust() {
        let dust = SKEmitterNode()
        dust.particleTexture = Textures.softDot
        dust.particleBirthRate = 8
        dust.particleLifetime = 12
        dust.particleLifetimeRange = 5
        dust.particleAlpha = 0.12
        dust.particleAlphaRange = 0.08
        dust.particleAlphaSpeed = -0.008
        dust.particleScale = 0.04
        dust.particleScaleRange = 0.03
        dust.particleSpeed = 12
        dust.particleSpeedRange = 8
        dust.emissionAngle = .pi * 1.25
        dust.emissionAngleRange = .pi / 3
        dust.particlePositionRange = CGVector(dx: size.width * 1.5, dy: size.height * 1.5)
        dust.particleBlendMode = .add
        dust.targetNode = self
        dust.zPosition = -15
        cam.addChild(dust)
    }

    // Ambient flybys — asteroids, comets, the odd rocket, and frequent shooting
    // stars — run in menu and gameplay alike (spawners live on the scene).
    private func startAmbientEvents() {
        run(.repeatForever(.sequence([
            .wait(forDuration: 7, withRange: 6),
            .run { [weak self] in self?.spawnAmbientEvent() },
        ])), withKey: "ambient")
        run(.repeatForever(.sequence([
            .wait(forDuration: 5, withRange: 4),
            .run { [weak self] in self?.spawnShootingStar() },
        ])), withKey: "shootingStars")
    }

    private func spawnAmbientEvent() {
        switch Int.random(in: 0..<10) {
        case 0..<4: spawnAsteroid()
        case 4..<8: spawnComet()
        default: spawnRocket()
        }
    }

    private func crossingCourse(margin: CGFloat, drift: CGFloat) -> (CGPoint, CGVector) {
        let fromLeft = Bool.random()
        let x = cam.position.x + (fromLeft ? -size.width / 2 - margin : size.width / 2 + margin)
        let y = cam.position.y + CGFloat.random(in: -size.height / 2 ... size.height / 2)
        let dx = (fromLeft ? 1 : -1) * (size.width + margin * 2)
        return (CGPoint(x: x, y: y), CGVector(dx: dx, dy: CGFloat.random(in: -drift...drift)))
    }

    private func spawnAsteroid() {
        guard let texture = Textures.asteroids.randomElement() else { return }
        let (start, delta) = crossingCourse(margin: 80, drift: 140)
        let asteroid = SKSpriteNode(texture: texture)
        asteroid.setScale(CGFloat.random(in: 0.35...0.9))
        asteroid.alpha = 0.85
        asteroid.zPosition = -8
        asteroid.position = start
        addChild(asteroid)
        let duration = TimeInterval.random(in: 7...12)
        asteroid.run(.group([
            .move(by: delta, duration: duration),
            .rotate(byAngle: CGFloat.random(in: -3...3), duration: duration),
        ]))
        asteroid.run(.sequence([.wait(forDuration: duration), .removeFromParent()]))
    }

    private func spawnComet() {
        let (start, delta) = crossingCourse(margin: 100, drift: 260)
        let comet = SKNode()
        comet.position = start
        comet.zPosition = -7
        let halo = SKSpriteNode(texture: Textures.softDot)
        halo.size = CGSize(width: 26, height: 26)
        halo.color = SKColor(red: 0.75, green: 0.95, blue: 1, alpha: 1)
        halo.colorBlendFactor = 1
        halo.blendMode = .add
        comet.addChild(halo)
        let core = SKShapeNode(circleOfRadius: 3.2)
        core.fillColor = .white
        core.strokeColor = .clear
        comet.addChild(core)
        let trail = SKEmitterNode()
        trail.particleTexture = Textures.softDot
        trail.particleBirthRate = 90
        trail.particleLifetime = 1.1
        trail.particleAlpha = 0.45
        trail.particleAlphaSpeed = -0.4
        trail.particleScale = 0.3
        trail.particleScaleSpeed = -0.25
        trail.particleBlendMode = .add
        trail.particleColor = SKColor(red: 0.6, green: 0.9, blue: 1, alpha: 1)
        trail.particleColorBlendFactor = 1
        trail.targetNode = self
        comet.addChild(trail)
        addChild(comet)
        comet.run(.sequence([
            .move(by: delta, duration: TimeInterval.random(in: 3.5...6)),
            .removeFromParent(),
        ]))
    }

    private func spawnShootingStar() {
        let (start, fullDelta) = crossingCourse(margin: 40, drift: 320)
        let delta = CGVector(dx: fullDelta.dx * 0.45, dy: fullDelta.dy)
        let star = SKNode()
        star.position = start
        star.zPosition = -9
        let head = SKSpriteNode(texture: Textures.softDot)
        head.size = CGSize(width: 14, height: 14)
        head.blendMode = .add
        star.addChild(head)
        let trail = SKEmitterNode()
        trail.particleTexture = Textures.softDot
        trail.particleBirthRate = 140
        trail.particleLifetime = 0.45
        trail.particleAlpha = 0.5
        trail.particleAlphaSpeed = -1.1
        trail.particleScale = 0.18
        trail.particleScaleSpeed = -0.35
        trail.particleBlendMode = .add
        trail.targetNode = self
        star.addChild(trail)
        addChild(star)
        star.run(.sequence([
            .move(by: delta, duration: TimeInterval.random(in: 0.7...1.2)),
            .fadeOut(withDuration: 0.15),
            .run { trail.particleBirthRate = 0 },
            .wait(forDuration: 0.5),
            .removeFromParent(),
        ]))
    }

    private func spawnRocket() {
        let (start, delta) = crossingCourse(margin: 120, drift: 200)
        let rocket = SKSpriteNode(texture: Textures.rocket)
        rocket.position = start
        rocket.zPosition = -6
        rocket.setScale(CGFloat.random(in: 0.8...1.1))
        rocket.zRotation = atan2(delta.dy, delta.dx) - .pi / 2
        let flame = SKEmitterNode()
        flame.particleTexture = Textures.softDot
        flame.particleBirthRate = 80
        flame.particleLifetime = 0.5
        flame.particleAlpha = 0.6
        flame.particleAlphaSpeed = -1.2
        flame.particleScale = 0.22
        flame.particleScaleSpeed = -0.3
        flame.particleBlendMode = .add
        flame.particleColor = SKColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1)
        flame.particleColorBlendFactor = 1
        flame.position = CGPoint(x: 0, y: -26)
        flame.targetNode = self
        rocket.addChild(flame)
        addChild(rocket)
        rocket.run(.sequence([
            .move(by: delta, duration: TimeInterval.random(in: 6...9)),
            .removeFromParent(),
        ]))
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

        levelLabel.fontSize = 14
        levelLabel.fontColor = Palette.textDim
        levelLabel.verticalAlignmentMode = .top
        cam.addChild(levelLabel)

        dailyTag.fontSize = 14
        dailyTag.fontColor = Palette.gold
        dailyTag.verticalAlignmentMode = .top
        dailyTag.isHidden = true
        cam.addChild(dailyTag)

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

        dailyButton = SKShapeNode(rectOf: CGSize(width: 268, height: 58), cornerRadius: 14)
        dailyButton.fillColor = SKColor(white: 1, alpha: 0.05)
        dailyButton.strokeColor = Palette.gold.withAlphaComponent(0.65)
        dailyButton.lineWidth = 1.5
        menuLayer.addChild(dailyButton)

        dailyTitleLabel.text = "DAILY CHALLENGE"
        dailyTitleLabel.fontSize = 16
        dailyTitleLabel.fontColor = Palette.gold
        dailyTitleLabel.verticalAlignmentMode = .center
        dailyTitleLabel.position = CGPoint(x: 0, y: 10)
        dailyButton.addChild(dailyTitleLabel)

        dailySubLabel.fontSize = 11
        dailySubLabel.fontColor = Palette.textDim
        dailySubLabel.verticalAlignmentMode = .center
        dailySubLabel.position = CGPoint(x: 0, y: -12)
        dailyButton.addChild(dailySubLabel)

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

        overStreakLabel.fontSize = 15
        overStreakLabel.fontColor = Palette.gold
        gameOverLayer.addChild(overStreakLabel)

        overTapLabel.text = "TAP TO RETRY"
        overTapLabel.fontSize = 17
        overTapLabel.fontColor = Palette.textDim
        overTapLabel.run(pulseForever())
        gameOverLayer.addChild(overTapLabel)

        menuButtonLabel.text = "MENU"
        menuButtonLabel.fontSize = 15
        menuButtonLabel.fontColor = Palette.textDim
        gameOverLayer.addChild(menuButtonLabel)

        layoutHUD()
    }

    private func pulseForever() -> SKAction {
        .repeatForever(.sequence([.fadeAlpha(to: 0.25, duration: 0.9),
                                  .fadeAlpha(to: 1.0, duration: 0.9)]))
    }

    private func layoutHUD() {
        let h = size.height
        scoreLabel.position = CGPoint(x: 0, y: h / 2 - 64)
        levelLabel.position = CGPoint(x: 0, y: h / 2 - 136)
        dailyTag.position = CGPoint(x: 0, y: h / 2 - 158)

        titleLabel.position = CGPoint(x: 0, y: h * 0.24)
        menuBestLabel.position = CGPoint(x: 0, y: h * 0.24 - 44)
        menuTapLabel.position = CGPoint(x: 0, y: -h * 0.24)
        dailyButton.position = CGPoint(x: 0, y: -h * 0.35)

        dimNode.size = CGSize(width: size.width, height: h)
        overCaptionLabel.position = CGPoint(x: 0, y: 96)
        finalScoreLabel.position = CGPoint(x: 0, y: 20)
        finalBestLabel.position = CGPoint(x: 0, y: -56)
        overStreakLabel.position = CGPoint(x: 0, y: -90)
        overTapLabel.position = CGPoint(x: 0, y: -h * 0.26)
        menuButtonLabel.position = CGPoint(x: 0, y: -h * 0.37)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard cam.parent != nil else { return }
        layoutHUD()
    }

    // MARK: - Run lifecycle

    private func startRun(showMenu: Bool) {
        if showMenu { mode = .classic }
        rng = SeededRandom(seed: mode == .daily ? Daily.seed : UInt64.random(in: .min ... .max))

        for planet in planets { planet.removeFromParent() }
        planets.removeAll()
        planetCount = 0
        currentIndex = 0
        captured = 0
        lastLevel = 1
        score = 0
        levelLabel.text = "LEVEL 1"
        levelLabel.isHidden = showMenu

        let first = makePlanet(ringRadius: 105, at: .zero)
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

        if mode == .daily {
            let streak = Daily.registerPlay()
            dailyTag.text = "DAILY · 🔥 \(streak)"
        }
        dailyTag.isHidden = showMenu || mode == .classic

        if showMenu {
            menuBestLabel.text = "BEST \(best)"
            menuBestLabel.isHidden = best == 0
            let streak = Daily.currentStreak
            if streak > 0 {
                let bestToday = Daily.bestToday
                dailySubLabel.text = bestToday > 0
                    ? "🔥 \(streak) DAY STREAK · BEST TODAY \(bestToday)"
                    : "🔥 \(streak) DAY STREAK"
            } else {
                dailySubLabel.text = "SAME RUN FOR EVERYONE · START A STREAK"
            }
        }
    }

    private func makePlanet(ringRadius: CGFloat, at position: CGPoint) -> Planet {
        let speed = min(baseOrbitSpeed + CGFloat(planetCount) * 0.045, maxOrbitSpeed)
        let planet = Planet(ringRadius: ringRadius,
                            coreRadius: rng.cgFloat(in: 10...16),
                            orbitSpeed: speed,
                            color: Palette.planetColor(index: planetCount))
        planet.position = position
        planet.sprinkleStars()
        planetCount += 1
        return planet
    }

    private func spawnNext() {
        guard let last = planets.last else { return }
        let distance = rng.cgFloat(in: 270...420)
        let spread: CGFloat = .pi * 0.36
        let angle = CGFloat.pi / 2 + rng.cgFloat(in: -spread...spread)
        let planet = makePlanet(ringRadius: rng.cgFloat(in: ringRadiusRange(for: level)),
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

        captured += 1
        if level > lastLevel {
            lastLevel = level
            levelLabel.text = "LEVEL \(level)"
            let announce = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            announce.text = "LEVEL \(level)"
            announce.fontSize = 30
            announce.fontColor = Palette.gold
            announce.position = CGPoint(x: 0, y: size.height * 0.16)
            announce.zPosition = 90
            announce.alpha = 0
            announce.setScale(0.7)
            cam.addChild(announce)
            announce.run(.sequence([
                .group([.fadeIn(withDuration: 0.2), .scale(to: 1, duration: 0.25)]),
                .wait(forDuration: 0.9),
                .fadeOut(withDuration: 0.4),
                .removeFromParent(),
            ]))
        }

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

        switch mode {
        case .classic:
            if score > best {
                best = score
                UserDefaults.standard.set(best, forKey: "bestScore")
            }
        case .daily:
            Daily.recordScore(score)
        }
        Backend.submitScore(score)

        gameOverReady = false
        run(.sequence([.wait(forDuration: 0.55),
                       .run { [weak self] in self?.showGameOver() }]))
    }

    private func showGameOver() {
        finalScoreLabel.text = "\(score)"
        switch mode {
        case .classic:
            overCaptionLabel.text = "SCORE"
            finalBestLabel.text = "BEST \(best)"
            overStreakLabel.isHidden = true
        case .daily:
            overCaptionLabel.text = "DAILY CHALLENGE"
            finalBestLabel.text = "BEST TODAY \(Daily.bestToday)"
            overStreakLabel.text = "🔥 \(Daily.currentStreak) DAY STREAK"
            overStreakLabel.isHidden = false
        }
        scoreLabel.isHidden = true
        levelLabel.isHidden = true
        dailyTag.isHidden = true
        gameOverLayer.alpha = 0
        gameOverLayer.isHidden = false
        gameOverLayer.run(.fadeIn(withDuration: 0.25))
        gameOverReady = true
        AdsManager.shared.gameEnded(score: score)
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        switch state {
        case .menu:
            let location = touch.location(in: menuLayer)
            if dailyButton.calculateAccumulatedFrame().insetBy(dx: -18, dy: -14).contains(location) {
                mode = .daily
                startRun(showMenu: false)
            } else {
                menuLayer.isHidden = true
                scoreLabel.isHidden = false
                levelLabel.isHidden = false
                state = .orbiting
            }
            Haptics.tap()
        case .orbiting:
            launch()
        case .flying:
            break
        case .dead:
            guard gameOverReady else { return }
            let location = touch.location(in: gameOverLayer)
            if menuButtonLabel.frame.insetBy(dx: -28, dy: -20).contains(location) {
                startRun(showMenu: true)
            } else {
                startRun(showMenu: false)
            }
        }
    }
}
