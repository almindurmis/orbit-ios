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

    // Power-up state
    private var shieldHeld = false
    private var magnetRemaining = 0
    private var shieldNode: SKShapeNode?
    private let magnetBonus: CGFloat = 26

    private var pilotLeveledUp = false

    // Obstacles (nodes live as children of the planet they guard; these arrays
    // are pruned when their planet is culled).
    private var walls: [AsteroidWall] = []
    private var bouncers: [Bouncer] = []
    private var gates: [(planet: Planet, gate: RotatingGate)] = []
    private var grazedThisFlight = false
    private var lastBounce: (bouncer: Bouncer, time: TimeInterval)?

    // PERFECT streak combo: consecutive dead-center captures multiply the base
    // score (×2, ×3… capped ×5); one sloppy capture breaks it.
    private var perfectStreak = 0
    private var comboFlame: SKEmitterNode!
    private var hitStopUntil: TimeInterval = 0
    private var shakeAmp: CGFloat = 0

    // Per-run stats fed into the daily missions at death.
    private var stats = Missions.RunStats()
    private var completedMissions: [Missions.Mission] = []

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
    private var menuButton: SKShapeNode!
    private let menuPilotLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private var xpBarBg: SKShapeNode!
    private var xpBarFill: SKSpriteNode!
    private let overXPLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")

    // Combo + sector HUD
    private let comboLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private var sectorTint: SKSpriteNode!

    // Menu hub cards
    private var pilotCard: SKShapeNode!
    private var pilotRing: SKShapeNode!
    private var pilotRingArc = SKShapeNode()
    private let pilotRingLevelLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let pilotXPTextLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let bestCaptionLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private var missionsCard: SKShapeNode!
    private let missionsTitleLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private var missionRowTitles: [SKLabelNode] = []
    private var missionRowStates: [SKLabelNode] = []
    private let dailyCountdownLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")

    // Game-over summary card
    private var overPanel: SKShapeNode!
    private var bestBarBg: SKShapeNode!
    private var bestBarFill: SKSpriteNode!
    private let bestBarLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private var overXPBarBg: SKShapeNode!
    private var overXPBarFill: SKSpriteNode!
    private var missionDoneLabels: [SKLabelNode] = []

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = Palette.background
        setupPlayer()
        buildHUD()
        setupSpaceDust()
        startAmbientEvents()
        Sound.start(on: self)
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

        // Burns while a PERFECT streak is hot — intensity and color climb with it.
        comboFlame = SKEmitterNode()
        comboFlame.particleTexture = Textures.softDot
        comboFlame.particleBirthRate = 0
        comboFlame.particleLifetime = 0.5
        comboFlame.particleAlpha = 0.6
        comboFlame.particleAlphaSpeed = -1.2
        comboFlame.particleScale = 0.3
        comboFlame.particleScaleSpeed = -0.4
        comboFlame.particleSpeed = 30
        comboFlame.emissionAngleRange = .pi * 2
        comboFlame.particleBlendMode = .add
        comboFlame.particleColor = Palette.gold
        comboFlame.particleColorBlendFactor = 1
        comboFlame.targetNode = self
        comboFlame.zPosition = -1
        player.addChild(comboFlame)

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

        comboLabel.fontSize = 15
        comboLabel.fontColor = Palette.gold
        comboLabel.verticalAlignmentMode = .top
        comboLabel.isHidden = true
        cam.addChild(comboLabel)

        dailyTag.fontSize = 14
        dailyTag.fontColor = Palette.gold
        dailyTag.verticalAlignmentMode = .top
        dailyTag.isHidden = true
        cam.addChild(dailyTag)

        // A soft full-screen wash in the sector's hue — crossfades on sector change.
        sectorTint = SKSpriteNode(texture: Textures.softDot)
        sectorTint.size = CGSize(width: max(size.width, size.height) * 2.6,
                                 height: max(size.width, size.height) * 2.6)
        sectorTint.color = Sectors.sector(for: 1).color
        sectorTint.colorBlendFactor = 1
        sectorTint.alpha = 0.12
        sectorTint.blendMode = .add
        sectorTint.zPosition = -30
        cam.addChild(sectorTint)

        menuLayer.zPosition = 100
        cam.addChild(menuLayer)

        titleLabel.text = "O R B I T"
        titleLabel.fontSize = 64
        titleLabel.fontColor = Palette.textPrimary
        menuLayer.addChild(titleLabel)

        // Pilot card: level ring (arc tinted with the trail color), XP bar, best score.
        pilotCard = SKShapeNode(rectOf: CGSize(width: 300, height: 92), cornerRadius: 16)
        pilotCard.fillColor = SKColor(red: 0.02, green: 0.03, blue: 0.09, alpha: 0.72)
        pilotCard.strokeColor = Palette.cyan.withAlphaComponent(0.3)
        pilotCard.lineWidth = 1
        menuLayer.addChild(pilotCard)

        pilotRing = SKShapeNode(circleOfRadius: 26)
        pilotRing.strokeColor = SKColor(white: 1, alpha: 0.12)
        pilotRing.lineWidth = 4
        pilotRing.fillColor = .clear
        pilotRing.position = CGPoint(x: -108, y: 0)
        pilotCard.addChild(pilotRing)

        pilotRingArc.strokeColor = Palette.cyan
        pilotRingArc.lineWidth = 4
        pilotRingArc.lineCap = .round
        pilotRingArc.fillColor = .clear
        pilotRing.addChild(pilotRingArc)

        pilotRingLevelLabel.fontSize = 20
        pilotRingLevelLabel.fontColor = Palette.textPrimary
        pilotRingLevelLabel.verticalAlignmentMode = .center
        pilotRing.addChild(pilotRingLevelLabel)

        menuPilotLabel.fontSize = 15
        menuPilotLabel.fontColor = Palette.textPrimary
        menuPilotLabel.horizontalAlignmentMode = .left
        menuPilotLabel.verticalAlignmentMode = .center
        menuPilotLabel.position = CGPoint(x: -70, y: 18)
        pilotCard.addChild(menuPilotLabel)

        pilotXPTextLabel.fontSize = 11
        pilotXPTextLabel.fontColor = Palette.textDim
        pilotXPTextLabel.horizontalAlignmentMode = .left
        pilotXPTextLabel.verticalAlignmentMode = .center
        pilotXPTextLabel.position = CGPoint(x: -70, y: -3)
        pilotCard.addChild(pilotXPTextLabel)

        xpBarBg = SKShapeNode(rectOf: CGSize(width: 130, height: 5), cornerRadius: 2.5)
        xpBarBg.fillColor = SKColor(white: 1, alpha: 0.12)
        xpBarBg.strokeColor = .clear
        xpBarBg.position = CGPoint(x: -5, y: -22)
        pilotCard.addChild(xpBarBg)

        xpBarFill = SKSpriteNode(color: Palette.cyan, size: CGSize(width: 0, height: 5))
        xpBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        xpBarFill.position = CGPoint(x: -65, y: 0)
        xpBarBg.addChild(xpBarFill)

        bestCaptionLabel.text = "BEST"
        bestCaptionLabel.fontSize = 10
        bestCaptionLabel.fontColor = Palette.textDim
        bestCaptionLabel.verticalAlignmentMode = .center
        bestCaptionLabel.position = CGPoint(x: 108, y: 18)
        pilotCard.addChild(bestCaptionLabel)

        menuBestLabel.fontSize = 26
        menuBestLabel.fontColor = Palette.textPrimary
        menuBestLabel.verticalAlignmentMode = .center
        menuBestLabel.position = CGPoint(x: 108, y: -8)
        pilotCard.addChild(menuBestLabel)

        // Daily missions card: three seeded goals, refreshed every midnight.
        missionsCard = SKShapeNode(rectOf: CGSize(width: 300, height: 112), cornerRadius: 16)
        missionsCard.fillColor = SKColor(red: 0.02, green: 0.03, blue: 0.09, alpha: 0.72)
        missionsCard.strokeColor = Palette.gold.withAlphaComponent(0.25)
        missionsCard.lineWidth = 1
        menuLayer.addChild(missionsCard)

        missionsTitleLabel.text = "DAILY MISSIONS"
        missionsTitleLabel.fontSize = 12
        missionsTitleLabel.fontColor = Palette.gold
        missionsTitleLabel.verticalAlignmentMode = .center
        missionsTitleLabel.position = CGPoint(x: 0, y: 38)
        missionsCard.addChild(missionsTitleLabel)

        for i in 0..<3 {
            let y = CGFloat(12 - i * 22)
            let title = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
            title.fontSize = 11.5
            title.horizontalAlignmentMode = .left
            title.verticalAlignmentMode = .center
            title.position = CGPoint(x: -132, y: y)
            missionsCard.addChild(title)
            missionRowTitles.append(title)

            let state = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
            state.fontSize = 11.5
            state.horizontalAlignmentMode = .right
            state.verticalAlignmentMode = .center
            state.position = CGPoint(x: 132, y: y)
            missionsCard.addChild(state)
            missionRowStates.append(state)
        }

        menuTapLabel.text = "TAP TO PLAY"
        menuTapLabel.fontSize = 18
        menuTapLabel.fontColor = Palette.cyan
        menuTapLabel.run(pulseForever())
        menuLayer.addChild(menuTapLabel)

        dailyButton = SKShapeNode(rectOf: CGSize(width: 300, height: 74), cornerRadius: 16)
        dailyButton.fillColor = SKColor(red: 0.02, green: 0.03, blue: 0.09, alpha: 0.72)
        dailyButton.strokeColor = Palette.gold.withAlphaComponent(0.65)
        dailyButton.lineWidth = 1.5
        menuLayer.addChild(dailyButton)

        dailyTitleLabel.text = "DAILY CHALLENGE"
        dailyTitleLabel.fontSize = 16
        dailyTitleLabel.fontColor = Palette.gold
        dailyTitleLabel.verticalAlignmentMode = .center
        dailyTitleLabel.position = CGPoint(x: 0, y: 20)
        dailyButton.addChild(dailyTitleLabel)

        dailySubLabel.fontSize = 11
        dailySubLabel.fontColor = Palette.textDim
        dailySubLabel.verticalAlignmentMode = .center
        dailySubLabel.position = CGPoint(x: 0, y: 0)
        dailyButton.addChild(dailySubLabel)

        dailyCountdownLabel.fontSize = 10
        dailyCountdownLabel.fontColor = SKColor(white: 1, alpha: 0.3)
        dailyCountdownLabel.verticalAlignmentMode = .center
        dailyCountdownLabel.position = CGPoint(x: 0, y: -20)
        dailyButton.addChild(dailyCountdownLabel)

        gameOverLayer.zPosition = 100
        gameOverLayer.isHidden = true
        cam.addChild(gameOverLayer)

        gameOverLayer.addChild(dimNode)

        // Run summary card: score, distance-to-best bar, streak, XP, missions.
        overPanel = SKShapeNode(rectOf: CGSize(width: 320, height: 340), cornerRadius: 20)
        overPanel.fillColor = SKColor(red: 0.02, green: 0.03, blue: 0.09, alpha: 0.8)
        overPanel.strokeColor = SKColor(white: 1, alpha: 0.14)
        overPanel.lineWidth = 1
        gameOverLayer.addChild(overPanel)

        overCaptionLabel.text = "SCORE"
        overCaptionLabel.fontSize = 14
        overCaptionLabel.fontColor = Palette.textDim
        overCaptionLabel.verticalAlignmentMode = .center
        overCaptionLabel.position = CGPoint(x: 0, y: 140)
        overPanel.addChild(overCaptionLabel)

        finalScoreLabel.fontSize = 68
        finalScoreLabel.fontColor = Palette.textPrimary
        finalScoreLabel.verticalAlignmentMode = .center
        finalScoreLabel.position = CGPoint(x: 0, y: 92)
        overPanel.addChild(finalScoreLabel)

        bestBarLabel.fontSize = 12
        bestBarLabel.fontColor = Palette.textDim
        bestBarLabel.verticalAlignmentMode = .center
        bestBarLabel.position = CGPoint(x: 0, y: 44)
        overPanel.addChild(bestBarLabel)

        bestBarBg = SKShapeNode(rectOf: CGSize(width: 220, height: 8), cornerRadius: 4)
        bestBarBg.fillColor = SKColor(white: 1, alpha: 0.1)
        bestBarBg.strokeColor = .clear
        bestBarBg.position = CGPoint(x: 0, y: 26)
        overPanel.addChild(bestBarBg)

        bestBarFill = SKSpriteNode(color: Palette.gold, size: CGSize(width: 0, height: 8))
        bestBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        bestBarFill.position = CGPoint(x: -110, y: 0)
        bestBarBg.addChild(bestBarFill)

        overStreakLabel.fontSize = 13
        overStreakLabel.fontColor = Palette.gold
        overStreakLabel.verticalAlignmentMode = .center
        overStreakLabel.position = CGPoint(x: 0, y: 0)
        overPanel.addChild(overStreakLabel)

        overXPLabel.fontSize = 13
        overXPLabel.fontColor = Palette.cyan
        overXPLabel.verticalAlignmentMode = .center
        overXPLabel.position = CGPoint(x: 0, y: -26)
        overPanel.addChild(overXPLabel)

        overXPBarBg = SKShapeNode(rectOf: CGSize(width: 220, height: 6), cornerRadius: 3)
        overXPBarBg.fillColor = SKColor(white: 1, alpha: 0.1)
        overXPBarBg.strokeColor = .clear
        overXPBarBg.position = CGPoint(x: 0, y: -46)
        overPanel.addChild(overXPBarBg)

        overXPBarFill = SKSpriteNode(color: Palette.cyan, size: CGSize(width: 0, height: 6))
        overXPBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        overXPBarFill.position = CGPoint(x: -110, y: 0)
        overXPBarBg.addChild(overXPBarFill)

        for i in 0..<3 {
            let label = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
            label.fontSize = 11.5
            label.fontColor = Palette.gold
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: CGFloat(-76 - i * 21))
            label.isHidden = true
            overPanel.addChild(label)
            missionDoneLabels.append(label)
        }

        // Kept for the pre-panel layout path; the panel's bar replaced it visually.
        finalBestLabel.fontSize = 17
        finalBestLabel.fontColor = Palette.textDim
        finalBestLabel.isHidden = true
        gameOverLayer.addChild(finalBestLabel)

        overTapLabel.text = "TAP TO RETRY"
        overTapLabel.fontSize = 18
        overTapLabel.fontColor = Palette.cyan
        overTapLabel.run(pulseForever())
        gameOverLayer.addChild(overTapLabel)

        menuButton = SKShapeNode(rectOf: CGSize(width: 148, height: 46), cornerRadius: 23)
        menuButton.fillColor = SKColor(white: 1, alpha: 0.10)
        menuButton.strokeColor = SKColor(white: 1, alpha: 0.22)
        menuButton.lineWidth = 1
        menuButton.run(.repeatForever(.sequence([.fadeAlpha(to: 0.7, duration: 1.4),
                                                 .fadeAlpha(to: 1.0, duration: 1.4)])))
        gameOverLayer.addChild(menuButton)

        menuButtonLabel.text = "MENU"
        menuButtonLabel.fontSize = 15
        menuButtonLabel.fontColor = Palette.textPrimary
        menuButtonLabel.verticalAlignmentMode = .center
        menuButton.addChild(menuButtonLabel)

        layoutHUD()
    }

    private func pulseForever() -> SKAction {
        .repeatForever(.sequence([.fadeAlpha(to: 0.25, duration: 0.9),
                                  .fadeAlpha(to: 1.0, duration: 0.9)]))
    }

    private func layoutHUD() {
        let h = size.height
        sectorTint.size = CGSize(width: max(size.width, h) * 2.6,
                                 height: max(size.width, h) * 2.6)
        scoreLabel.position = CGPoint(x: 0, y: h / 2 - 64)
        levelLabel.position = CGPoint(x: 0, y: h / 2 - 136)
        comboLabel.position = CGPoint(x: 0, y: h / 2 - 158)
        dailyTag.position = CGPoint(x: 0, y: h / 2 - 182)

        titleLabel.position = CGPoint(x: 0, y: h * 0.30)
        pilotCard.position = CGPoint(x: 0, y: h * 0.30 - 100)
        missionsCard.position = CGPoint(x: 0, y: h * 0.30 - 212)
        menuTapLabel.position = CGPoint(x: 0, y: -h * 0.17)
        dailyButton.position = CGPoint(x: 0, y: -h * 0.17 - 88)

        dimNode.size = CGSize(width: size.width, height: h)
        overPanel.position = CGPoint(x: 0, y: h * 0.06)
        overTapLabel.position = CGPoint(x: 0, y: -h * 0.28)
        menuButton.position = CGPoint(x: 0, y: -h * 0.38)
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
        walls.removeAll()
        bouncers.removeAll()
        gates.removeAll()
        planetCount = 0
        currentIndex = 0
        captured = 0
        lastLevel = 1
        score = 0
        levelLabel.text = "SECTOR 1 · \(Sectors.sector(for: 1).name)"
        levelLabel.isHidden = showMenu
        sectorTint.removeAllActions()
        sectorTint.color = Sectors.sector(for: 1).color

        perfectStreak = 0
        comboLabel.isHidden = true
        comboFlame.particleBirthRate = 0
        hitStopUntil = 0
        shakeAmp = 0
        grazedThisFlight = false
        lastBounce = nil
        stats = Missions.RunStats()
        completedMissions = []

        let first = makePlanet(ringRadius: 105, at: .zero)
        addChild(first)
        planets.append(first)
        spawnNext()

        shieldHeld = false
        shieldNode?.removeFromParent()
        shieldNode = nil
        magnetRemaining = 0

        orbitAngle = -.pi / 2
        orbitSpin = 1
        orbitSpeed = first.orbitSpeed
        player.position = first.position + .polar(angle: orbitAngle, radius: first.ringRadius)
        player.alpha = 1
        trail.particleBirthRate = 45
        trail.particleColor = Progress.trailColor
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
            refreshMenuHub()
        } else {
            removeAction(forKey: "menuTick")
        }
    }

    // MARK: - Menu hub

    private func refreshMenuHub() {
        menuBestLabel.text = "\(best)"
        menuBestLabel.isHidden = best == 0
        bestCaptionLabel.isHidden = best == 0
        menuPilotLabel.text = "PILOT LV \(Progress.level)"
        pilotXPTextLabel.text = "\(Progress.xpIntoLevel) / \(Progress.xpForNextLevel) XP"
        pilotRingLevelLabel.text = "\(Progress.level)"

        let fraction = CGFloat(Progress.xpIntoLevel) / CGFloat(max(1, Progress.xpForNextLevel))
        xpBarFill.size.width = 130 * fraction

        // Ring arc doubles as the trail-color preview.
        let trail = Progress.trailColor
        pilotRingArc.strokeColor = trail == .white ? Palette.cyan : trail
        xpBarFill.color = pilotRingArc.strokeColor
        if fraction > 0.01 {
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: 26, startAngle: -.pi / 2,
                        endAngle: -.pi / 2 + fraction * 2 * .pi, clockwise: false)
            pilotRingArc.path = path
        } else {
            pilotRingArc.path = nil
        }

        let missions = Missions.today
        for (i, mission) in missions.enumerated() where i < missionRowTitles.count {
            let done = Missions.isComplete(mission)
            missionRowTitles[i].text = mission.title
            missionRowTitles[i].fontColor = done ? Palette.gold : SKColor(white: 1, alpha: 0.85)
            missionRowStates[i].text = done ? "✓ +\(mission.xp) XP"
                : "\(Missions.progress(mission))/\(mission.target)"
            missionRowStates[i].fontColor = done ? Palette.gold : Palette.textDim
        }

        let streak = Daily.currentStreak
        if streak > 0 {
            let bestToday = Daily.bestToday
            dailySubLabel.text = bestToday > 0
                ? "🔥 \(streak) DAY STREAK · BEST TODAY \(bestToday)"
                : "🔥 \(streak) DAY STREAK"
        } else {
            dailySubLabel.text = "SAME RUN FOR EVERYONE · START A STREAK"
        }

        dailyCountdownLabel.text = dailyCountdownText()
        removeAction(forKey: "menuTick")
        run(.repeatForever(.sequence([
            .wait(forDuration: 1),
            .run { [weak self] in self?.dailyCountdownLabel.text = self?.dailyCountdownText() },
        ])), withKey: "menuTick")
    }

    private func dailyCountdownText() -> String {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return "" }
        let s = max(0, Int(next.timeIntervalSince(now)))
        return String(format: "NEW RUN IN %02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private func makePlanet(ringRadius: CGFloat, at position: CGPoint,
                            kind: PlanetKind = .normal) -> Planet {
        let speed = min(baseOrbitSpeed + CGFloat(planetCount) * 0.045, maxOrbitSpeed)
        let sector = Sectors.sector(for: level)
        let color: SKColor
        switch kind {
        case .normal: color = Palette.planetColor(index: planetCount, sectorHue: sector.hue)
        case .golden: color = Palette.gold
        case .shield: color = Palette.shieldBlue
        case .magnet: color = Palette.magnetViolet
        case .unstable: color = Palette.unstableRed
        }
        let planet = Planet(ringRadius: ringRadius,
                            coreRadius: rng.cgFloat(in: 10...16),
                            orbitSpeed: speed,
                            color: color,
                            kind: kind)
        planet.position = position
        planet.sprinkleStars(nebulaHue: sector.hue)
        planetCount += 1
        return planet
    }

    // Deterministic (seeded) so daily runs stay identical for everyone.
    private func rollKind() -> PlanetKind {
        // Marketing captures: surface the special planets early and predictably.
        if ProcessInfo.processInfo.arguments.contains("-screenshots") {
            switch planetCount % 4 {
            case 1: return .golden
            case 2: return .shield
            case 3: return .magnet
            default: return .unstable
            }
        }
        guard planetCount >= 5 else { return .normal }
        let roll = rng.cgFloat(in: 0...1)
        switch roll {
        case ..<0.07: return .golden
        case ..<0.12: return .shield
        case ..<0.17: return .magnet
        case ..<0.22: return .unstable
        default: return .normal
        }
    }

    private func spawnNext() {
        guard let last = planets.last else { return }
        let distance = rng.cgFloat(in: 270...420)
        let spread: CGFloat = .pi * 0.36
        let angle = CGFloat.pi / 2 + rng.cgFloat(in: -spread...spread)
        let planet = makePlanet(ringRadius: rng.cgFloat(in: ringRadiusRange(for: level)),
                                at: last.position + .polar(angle: angle, radius: distance),
                                kind: rollKind())
        addChild(planet)
        planets.append(planet)
        spawnObstacles(from: last, to: planet)
    }

    // MARK: - Obstacles

    // Seeded like everything else, so daily layouts match for everyone. Nodes are
    // children of the guarded (target) planet and get culled with it.
    private func spawnObstacles(from last: Planet, to planet: Planet) {
        let forceShots = ProcessInfo.processInfo.arguments.contains("-screenshots")
        let sector = Sectors.sector(for: level)
        let toNew = planet.position - last.position
        let dir = toNew.normalized
        let perp = CGPoint(x: -dir.y, y: dir.x)

        // Asteroid wall from sector 3: rocks jut in from one side of the corridor,
        // always leaving the center line clear so a well-timed shot exists.
        let wallChance: CGFloat = level >= 3 ? min(0.22 + CGFloat(level) * 0.03, 0.5) : 0
        let wantWall = forceShots ? planetCount == 2 : rng.cgFloat(in: 0...1) < wallChance
        if wantWall {
            let t = rng.cgFloat(in: 0.42...0.6)
            let side: CGFloat = rng.cgFloat(in: 0...1) < 0.5 ? 1 : -1
            let clearance = rng.cgFloat(in: 42...64)
            let count = 3 + Int(rng.next() % 3)
            var rocks: [AsteroidWall.Rock] = []
            for i in 0..<count {
                let radius = rng.cgFloat(in: 13...19)
                let along = clearance + CGFloat(i) * 34 + rng.cgFloat(in: -4...4)
                rocks.append(AsteroidWall.Rock(offset: perp * (side * along), radius: radius))
            }
            let wall = AsteroidWall(rocks: rocks, hue: sector.hue)
            wall.position = toNew * (t - 1)   // corridor point, in the new planet's frame
            planet.addChild(wall)
            walls.append(wall)
        }

        // Bouncer from sector 5: a springy orb beside the corridor.
        let bouncerChance: CGFloat = level >= 5 ? 0.28 : 0
        let wantBouncer = forceShots ? planetCount == 3 : rng.cgFloat(in: 0...1) < bouncerChance
        if wantBouncer {
            let t = rng.cgFloat(in: 0.35...0.65)
            let side: CGFloat = rng.cgFloat(in: 0...1) < 0.5 ? 1 : -1
            let lateral = rng.cgFloat(in: 55...105)
            let bouncer = Bouncer()
            bouncer.position = toNew * (t - 1) + perp * (side * lateral)
            planet.addChild(bouncer)
            bouncers.append(bouncer)
        }

        // Rotating gate from sector 8: an orbiting shield arc around the new planet.
        let gateChance: CGFloat = level >= 8 ? 0.3 : 0
        let wantGate = forceShots ? planetCount == 4 : rng.cgFloat(in: 0...1) < gateChance
        if wantGate {
            let spin: CGFloat = rng.cgFloat(in: 0...1) < 0.5 ? 1 : -1
            let gate = RotatingGate(orbitRadius: planet.ringRadius + 34,
                                    halfArc: rng.cgFloat(in: 0.55...0.8),
                                    angularSpeed: spin * rng.cgFloat(in: 0.8...1.3),
                                    color: sector.color)
            planet.addChild(gate)
            gates.append((planet, gate))
        }
    }

    private func pruneCulledObstacles() {
        walls.removeAll { $0.scene == nil }
        bouncers.removeAll { $0.scene == nil }
        gates.removeAll { $0.gate.scene == nil }
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat = lastUpdate == 0 ? 1.0 / 60.0 : CGFloat(min(currentTime - lastUpdate, 1.0 / 30.0))
        lastUpdate = currentTime

        // Hit-stop: a PERFECT freezes the world for a few frames — pure juice.
        if currentTime < hitStopUntil { return }

        switch state {
        case .menu, .orbiting:
            let planet = planets[currentIndex]
            planet.shrinkRing(dt: dt)
            orbitAngle += orbitSpin * orbitSpeed * dt
            player.position = planet.position + .polar(angle: orbitAngle, radius: planet.currentRingRadius)
            let tangent = tangentDirection()
            aim.zRotation = atan2(tangent.y, tangent.x)
        case .flying:
            updateFlight(dt: dt, currentTime: currentTime)
        case .dead:
            break
        }

        let goal = camTarget()
        let k = 1 - exp(-5 * dt)
        cam.position = CGPoint(x: cam.position.x + (goal.x - cam.position.x) * k,
                               y: cam.position.y + (goal.y - cam.position.y) * k)

        if shakeAmp > 0.5 {
            cam.position = cam.position + CGPoint(x: CGFloat.random(in: -1...1) * shakeAmp,
                                                  y: CGFloat.random(in: -1...1) * shakeAmp)
            shakeAmp *= exp(-6 * dt)
        } else {
            shakeAmp = 0
        }
    }

    private func updateFlight(dt: CGFloat, currentTime: TimeInterval) {
        player.position = player.position + velocity * dt
        let current = planets[currentIndex]
        let target = planets[currentIndex + 1]

        // Bouncers reflect the flight; the line is re-baselined so PERFECT and
        // miss detection follow the new trajectory.
        for bouncer in bouncers where bouncer.scene != nil {
            let center = convert(CGPoint.zero, from: bouncer)
            guard player.position.distance(to: center) <= Bouncer.radius + 7 else { continue }
            if let recent = lastBounce, recent.bouncer === bouncer,
               currentTime - recent.time < 0.3 { continue }
            let n = (player.position - center).normalized
            let dot = velocity.x * n.x + velocity.y * n.y
            velocity = CGPoint(x: velocity.x - 2 * dot * n.x, y: velocity.y - 2 * dot * n.y)
            launchOrigin = player.position
            launchDir = velocity.normalized
            prevTargetDistance = player.position.distance(to: target.position)
            lastBounce = (bouncer, currentTime)
            stats.bounces += 1
            bouncer.squash()
            Haptics.tap()
            Sound.play("bounce")
        }

        // Asteroid walls: a hit ends the flight (Shield saves); a survived graze
        // pays CLOSE CALL on the next capture.
        for wall in walls where wall.scene != nil {
            for rock in wall.rocks {
                let center = convert(rock.offset, from: wall)
                let d = player.position.distance(to: center)
                if d <= rock.radius + 6 {
                    crumble(at: player.position, hue: Sectors.sector(for: level).hue)
                    shakeAmp = max(shakeAmp, 8)
                    if shieldHeld { shieldRescue() } else { die() }
                    return
                } else if d <= rock.radius + 30 {
                    grazedThisFlight = true
                }
            }
        }

        // Rotating gates on the planet being left AND the one being approached.
        for planet in [current, target] {
            guard let gate = gates.first(where: { $0.planet === planet })?.gate,
                  gate.scene != nil else { continue }
            let d = player.position.distance(to: planet.position)
            guard abs(d - gate.orbitRadius) <= RotatingGate.bandHalfWidth else { continue }
            let v = player.position - planet.position
            if gate.isBlocking(angle: atan2(v.y, v.x)) {
                gateSpark(at: player.position)
                shakeAmp = max(shakeAmp, 8)
                if shieldHeld { shieldRescue() } else { die() }
                return
            }
        }

        // An active magnet widens the capture ring.
        let captureRadius = target.ringRadius + (magnetRemaining > 0 ? magnetBonus : 0)
        let d = player.position.distance(to: target.position)
        if d <= captureRadius && prevTargetDistance > captureRadius {
            capture(target)
        } else if d > prevTargetDistance && d > captureRadius + missMargin {
            if shieldHeld { shieldRescue() } else { die() }
        } else {
            prevTargetDistance = d
        }
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
        grazedThisFlight = false
        lastBounce = nil
        trail.particleBirthRate = 150
        aim.isHidden = true
        state = .flying
        Haptics.tap()
        Sound.play("launch")
    }

    // A held shield converts a miss into a rescue back to the current planet.
    private func shieldRescue() {
        shieldHeld = false
        shieldNode?.removeFromParent()
        shieldNode = nil

        let planet = planets[currentIndex]
        let radial = player.position - planet.position
        orbitAngle = atan2(radial.y, radial.x)
        orbitSpeed = planet.orbitSpeed
        player.position = planet.position + .polar(angle: orbitAngle, radius: planet.currentRingRadius)
        trail.particleBirthRate = 45
        aim.isHidden = false
        state = .orbiting

        popup(text: "SHIELD SAVED", color: Palette.shieldBlue, above: planet)
        Haptics.capture()
        Sound.play("shield")
    }

    private func attachShieldAura() {
        guard shieldNode == nil else { return }
        let aura = SKShapeNode(circleOfRadius: 16)
        aura.strokeColor = Palette.shieldBlue.withAlphaComponent(0.9)
        aura.lineWidth = 1.5
        aura.glowWidth = 3
        aura.zPosition = 1
        aura.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.45, duration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.6),
        ])))
        player.addChild(aura)
        shieldNode = aura
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
        player.position = target.position + .polar(angle: orbitAngle, radius: target.currentRingRadius)

        // The magnet that helped this capture is spent before a new one can arm.
        if magnetRemaining > 0 { magnetRemaining -= 1 }

        // Consecutive PERFECTs multiply the base score (×2, ×3… capped ×5).
        var points: Int
        var text: String
        var color: SKColor
        if perfect {
            perfectStreak += 1
            stats.perfects += 1
            stats.longestStreak = max(stats.longestStreak, perfectStreak)
            let multiplier = min(perfectStreak, 5)
            points = 2 * multiplier
            text = multiplier > 1 ? "PERFECT ×\(multiplier) +\(points)" : "PERFECT +2"
            color = Palette.gold
            hitStopUntil = lastUpdate + 0.07
        } else {
            perfectStreak = 0
            points = 1
            text = "+1"
            color = Palette.textDim
        }
        switch target.kind {
        case .normal:
            break
        case .golden:
            points *= 2
            text = "GOLDEN +\(points)"
            color = Palette.gold
        case .shield:
            shieldHeld = true
            attachShieldAura()
            text = "SHIELD +\(points)"
            color = Palette.shieldBlue
        case .magnet:
            magnetRemaining = 6
            text = "MAGNET +\(points)"
            color = Palette.magnetViolet
        case .unstable:
            points += 3
            text = "RISKY +\(points)"
            color = Palette.unstableRed
        }
        score += points
        popup(text: text, color: color, above: target, big: perfectStreak >= 3)

        // A survived wall graze pays out on landing.
        if grazedThisFlight {
            grazedThisFlight = false
            score += 2
            stats.closeCalls += 1
            let label = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
            label.text = "CLOSE CALL +2"
            label.fontSize = 15
            label.fontColor = Palette.bouncerPink
            label.position = target.position + CGPoint(x: 0, y: -target.ringRadius - 26)
            label.zPosition = 20
            addChild(label)
            label.run(.sequence([
                .group([.moveBy(x: 0, y: -30, duration: 0.7),
                        .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.3)])]),
                .removeFromParent(),
            ]))
        }

        shockwave(at: target, perfect: perfect)
        updateComboHUD()

        if target.kind != .normal {
            Sound.play("powerup")
        } else if perfect {
            Sound.play(perfectStreak >= 2 ? "streak" : "perfect")
        } else {
            Sound.plink(captured % 8)
        }

        captured += 1
        stats.captures = captured
        stats.maxLevel = max(stats.maxLevel, level)
        if level > lastLevel {
            lastLevel = level
            announceSector(Sectors.sector(for: level))
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
            pruneCulledObstacles()
        }
    }

    // Sector change: banner sweep + the background wash crossfades to the new hue.
    private func announceSector(_ sector: Sector) {
        levelLabel.text = "SECTOR \(sector.level) · \(sector.name)"
        sectorTint.run(.colorize(with: sector.color, colorBlendFactor: 1, duration: 1.2))

        let banner = SKNode()
        banner.zPosition = 90
        banner.position = CGPoint(x: 0, y: size.height * 0.16)
        cam.addChild(banner)

        let heading = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        heading.text = "SECTOR \(sector.level)"
        heading.fontSize = 32
        heading.fontColor = sector.color
        heading.verticalAlignmentMode = .center
        banner.addChild(heading)

        let name = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
        name.text = sector.name
        name.fontSize = 15
        name.fontColor = Palette.textDim
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: -26)
        banner.addChild(name)

        for sign: CGFloat in [-1, 1] {
            let line = SKSpriteNode(color: sector.color.withAlphaComponent(0.7),
                                    size: CGSize(width: 54, height: 1.5))
            line.position = CGPoint(x: sign * 128, y: 0)
            banner.addChild(line)
        }

        banner.alpha = 0
        banner.setScale(0.7)
        banner.run(.sequence([
            .group([.fadeIn(withDuration: 0.2), .scale(to: 1, duration: 0.25)]),
            .wait(forDuration: 1.1),
            .fadeOut(withDuration: 0.4),
            .removeFromParent(),
        ]))
        Sound.play("levelup")
    }

    private func updateComboHUD() {
        let hot = perfectStreak >= 2
        comboLabel.isHidden = !hot
        if hot {
            comboLabel.text = "PERFECT STREAK ×\(min(perfectStreak, 5))"
            comboLabel.fontColor = perfectStreak >= 4
                ? SKColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1) : Palette.gold
            comboLabel.removeAllActions()
            comboLabel.setScale(1.25)
            comboLabel.run(.scale(to: 1, duration: 0.18))
        }
        comboFlame.particleBirthRate = hot ? CGFloat(min(perfectStreak, 5)) * 14 : 0
        comboFlame.particleColor = perfectStreak >= 4
            ? SKColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 1) : Palette.gold
    }

    // MARK: - Effects

    private func shockwave(at planet: Planet, perfect: Bool) {
        let ring = SKShapeNode(circleOfRadius: planet.ringRadius)
        ring.strokeColor = perfect ? Palette.gold : SKColor(white: 1, alpha: 0.7)
        ring.lineWidth = perfect ? 3 : 2
        ring.glowWidth = perfect ? 5 : 3
        ring.fillColor = .clear
        ring.position = planet.position
        ring.zPosition = 8
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: perfect ? 1.7 : 1.45, duration: 0.35),
                    .fadeOut(withDuration: 0.35)]),
            .removeFromParent(),
        ]))
    }

    private func crumble(at point: CGPoint, hue: CGFloat) {
        let burst = SKEmitterNode()
        burst.particleTexture = Textures.softDot
        burst.particleBirthRate = 700
        burst.numParticlesToEmit = 26
        burst.particleLifetime = 0.6
        burst.particleSpeed = 140
        burst.particleSpeedRange = 90
        burst.emissionAngleRange = .pi * 2
        burst.particleAlpha = 0.8
        burst.particleAlphaSpeed = -1.4
        burst.particleScale = 0.3
        burst.particleScaleSpeed = -0.35
        burst.particleColor = SKColor(hue: hue, saturation: 0.35, brightness: 0.85, alpha: 1)
        burst.particleColorBlendFactor = 1
        burst.particleBlendMode = .add
        burst.position = point
        burst.zPosition = 15
        addChild(burst)
        burst.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
    }

    private func gateSpark(at point: CGPoint) {
        let burst = SKEmitterNode()
        burst.particleTexture = Textures.softDot
        burst.particleBirthRate = 900
        burst.numParticlesToEmit = 20
        burst.particleLifetime = 0.4
        burst.particleSpeed = 200
        burst.particleSpeedRange = 110
        burst.emissionAngleRange = .pi * 2
        burst.particleAlpha = 0.9
        burst.particleAlphaSpeed = -2.2
        burst.particleScale = 0.24
        burst.particleScaleSpeed = -0.3
        burst.particleColor = .white
        burst.particleColorBlendFactor = 1
        burst.particleBlendMode = .add
        burst.position = point
        burst.zPosition = 15
        addChild(burst)
        burst.run(.sequence([.wait(forDuration: 0.9), .removeFromParent()]))
    }

    private func popup(text: String, color: SKColor, above planet: Planet, big: Bool = false) {
        let label = SKLabelNode(fontNamed: big ? "HelveticaNeue-Bold" : "HelveticaNeue-Medium")
        label.text = text
        label.fontSize = big ? 27 : 22
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
        shieldNode?.removeFromParent()
        shieldNode = nil
        perfectStreak = 0
        comboFlame.particleBirthRate = 0
        comboLabel.isHidden = true
        shakeAmp = max(shakeAmp, 15)
        Haptics.death()
        Sound.play("death")

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
        stats.score = score
        let scoreLeveledUp = Progress.addXP(score)
        let missionResult = Missions.report(stats)
        completedMissions = missionResult.completed
        pilotLeveledUp = scoreLeveledUp || missionResult.leveledUp

        gameOverReady = false
        run(.sequence([.wait(forDuration: 0.55),
                       .run { [weak self] in self?.showGameOver() }]))
    }

    private func showGameOver() {
        finalScoreLabel.text = "\(score)"
        let reference: Int
        switch mode {
        case .classic:
            overCaptionLabel.text = "SCORE"
            reference = best
        case .daily:
            let streak = Daily.currentStreak
            overCaptionLabel.text = streak > 0 ? "DAILY CHALLENGE · 🔥 \(streak)" : "DAILY CHALLENGE"
            reference = Daily.bestToday
        }

        // How close this run came to the record — full gold bar on a new best.
        // Hidden entirely on a scoreless first run (no record to measure against).
        let newBest = score > 0 && score >= reference
        let ratio = reference > 0 ? min(CGFloat(score) / CGFloat(reference), 1) : 0
        let showBar = reference > 0
        bestBarLabel.isHidden = !showBar
        bestBarBg.isHidden = !showBar
        if newBest {
            bestBarLabel.text = mode == .daily ? "BEST TODAY!" : "NEW BEST!"
            bestBarLabel.fontColor = Palette.gold
        } else {
            bestBarLabel.text = "\(Int(ratio * 100))% OF BEST \(reference)"
            bestBarLabel.fontColor = Palette.textDim
        }
        bestBarFill.size.width = 0
        bestBarFill.color = newBest ? Palette.gold : Palette.cyan
        bestBarFill.run(.resize(toWidth: 220 * max(ratio, 0.02), duration: 0.6))

        if stats.longestStreak >= 2 {
            overStreakLabel.text = "LONGEST PERFECT STREAK ×\(min(stats.longestStreak, 5))"
            overStreakLabel.isHidden = false
        } else {
            overStreakLabel.isHidden = true
        }

        if pilotLeveledUp {
            overXPLabel.text = Progress.unlockedNewTrail
                ? "PILOT LV \(Progress.level) · NEW TRAIL COLOR"
                : "PILOT LEVEL UP · LV \(Progress.level)"
            overXPLabel.fontColor = Palette.gold
            Sound.play("levelup")
        } else {
            overXPLabel.text = "+\(score) XP · PILOT LV \(Progress.level)"
            overXPLabel.fontColor = Palette.cyan
        }
        overXPLabel.isHidden = score == 0
        let xpFraction = CGFloat(Progress.xpIntoLevel) / CGFloat(max(1, Progress.xpForNextLevel))
        overXPBarFill.size.width = 0
        overXPBarFill.run(.resize(toWidth: 220 * xpFraction, duration: 0.7))

        for (i, label) in missionDoneLabels.enumerated() {
            if i < completedMissions.count {
                let mission = completedMissions[i]
                label.text = "✓ \(mission.title)  +\(mission.xp) XP"
                label.alpha = 0
                label.isHidden = false
                label.run(.sequence([.wait(forDuration: 0.35 + Double(i) * 0.2),
                                     .fadeIn(withDuration: 0.3)]))
            } else {
                label.isHidden = true
            }
        }

        scoreLabel.isHidden = true
        levelLabel.isHidden = true
        comboLabel.isHidden = true
        dailyTag.isHidden = true
        gameOverLayer.alpha = 0
        gameOverLayer.isHidden = false
        overPanel.setScale(0.92)
        overPanel.run(.scale(to: 1, duration: 0.25))
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
                removeAction(forKey: "menuTick")
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
            if menuButton.frame.insetBy(dx: -16, dy: -14).contains(location) {
                startRun(showMenu: true)
            } else {
                startRun(showMenu: false)
            }
        }
    }
}
