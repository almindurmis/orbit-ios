import AVFoundation
import SpriteKit

// All audio is generated procedurally into Orbit/Sounds by Tools/make-sounds.swift.
// One-shots play through SKActions (cheap and overlapping); the ambient pad
// loops through AVAudioPlayer. The .ambient session respects the silent switch
// and mixes with the user's own music.
enum Sound {
    private static weak var host: SKNode?
    private static var actions: [String: SKAction] = [:]
    private static var pad: AVAudioPlayer?

    static func start(on node: SKNode) {
        host = node
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let names = ["perfect", "powerup", "shield", "death", "levelup", "launch"]
            + (0..<8).map { "plink\($0)" }
        for name in names where Bundle.main.url(forResource: name, withExtension: "wav") != nil {
            actions[name] = .playSoundFileNamed("\(name).wav", waitForCompletion: false)
        }
        if let url = Bundle.main.url(forResource: "ambient", withExtension: "wav") {
            pad = try? AVAudioPlayer(contentsOf: url)
            pad?.numberOfLoops = -1
            pad?.volume = 0.55
            pad?.play()
        }
    }

    static func play(_ name: String) {
        guard let action = actions[name] else { return }
        host?.run(action)
    }

    // Capture plinks climb a pentatonic ladder with the run.
    static func plink(_ step: Int) {
        play("plink\(max(0, min(step, 7)))")
    }
}
