import SpriteKit

// A translucent racer replaying recorded position samples. The scene drives it
// with the live run clock; positions interpolate between samples so playback is
// smooth regardless of frame rate.
final class GhostNode: SKNode {
    private let samples: [Double]   // flat [t, x, y] triples, time-ascending
    private var cursor = 0

    init(run: GhostRun, color: SKColor) {
        self.samples = run.samples
        super.init()
        zPosition = 9
        alpha = 0

        let halo = SKSpriteNode(texture: Textures.softDot)
        halo.size = CGSize(width: 34, height: 34)
        halo.color = color
        halo.colorBlendFactor = 1
        halo.blendMode = .add
        halo.alpha = 0.55
        addChild(halo)

        let core = SKShapeNode(circleOfRadius: 4.5)
        core.fillColor = color.withAlphaComponent(0.75)
        core.strokeColor = .clear
        addChild(core)

        let label = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
        label.text = run.isMine ? "YOU" : String(run.name.prefix(10)).uppercased()
        label.fontSize = 10
        label.fontColor = color.withAlphaComponent(0.85)
        label.position = CGPoint(x: 0, y: 12)
        addChild(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Move to the recorded position for `time`; fades in on first advance and
    /// out once the recording ends.
    func advance(to time: Double) {
        let count = samples.count / 3
        guard count >= 2 else { return }

        if alpha == 0 && time >= samples[0] {
            run(.fadeAlpha(to: 0.55, duration: 0.4))
        }
        let lastT = samples[(count - 1) * 3]
        if time >= lastT {
            position = CGPoint(x: samples[(count - 1) * 3 + 1], y: samples[(count - 1) * 3 + 2])
            if action(forKey: "ghostOut") == nil && alpha > 0.05 {
                run(.fadeAlpha(to: 0.0, duration: 1.2), withKey: "ghostOut")
            }
            return
        }

        while cursor < count - 2 && samples[(cursor + 1) * 3] <= time { cursor += 1 }
        let t0 = samples[cursor * 3]
        let t1 = samples[(cursor + 1) * 3]
        let f = t1 > t0 ? CGFloat((time - t0) / (t1 - t0)) : 0
        let x0 = CGFloat(samples[cursor * 3 + 1]), y0 = CGFloat(samples[cursor * 3 + 2])
        let x1 = CGFloat(samples[(cursor + 1) * 3 + 1]), y1 = CGFloat(samples[(cursor + 1) * 3 + 2])
        position = CGPoint(x: x0 + (x1 - x0) * min(max(f, 0), 1),
                           y: y0 + (y1 - y0) * min(max(f, 0), 1))
    }
}
