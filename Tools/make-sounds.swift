// Generates every sound in Orbit/Sounds as 16-bit mono WAVs.
// Run from the repo root: swift Tools/make-sounds.swift
//
// Sound design: deep space, not piano lessons — metallic FM tones on a dark
// phrygian ladder, sub-bass swells, dissonant beating drones. The ambient pad
// only uses frequencies that fit whole cycles into its 12s length (k/12 Hz),
// so it loops seamlessly.
import Foundation

let sampleRate = 44100.0
let outDir = "Orbit/Sounds"

func writeWav(_ samples: [Double], _ name: String) {
    var data = Data()
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    let n = samples.count
    data.append("RIFF".data(using: .ascii)!); u32(UInt32(36 + n * 2))
    data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(1)
    u32(UInt32(sampleRate)); u32(UInt32(sampleRate) * 2); u16(2); u16(16)
    data.append("data".data(using: .ascii)!); u32(UInt32(n * 2))
    for s in samples {
        let v = Int16(max(-1.0, min(1.0, s)) * 32767)
        withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) }
    }
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).wav"))
    print("wrote \(name).wav (\(n) samples)")
}

func envelope(_ t: Double, attack: Double, decay: Double) -> Double {
    t < attack ? t / attack : exp(-(t - attack) / decay)
}

func mix(_ tracks: [(offset: Double, samples: [Double])]) -> [Double] {
    let length = tracks.map { Int($0.offset * sampleRate) + $0.samples.count }.max() ?? 0
    var out = [Double](repeating: 0, count: length)
    for track in tracks {
        let start = Int(track.offset * sampleRate)
        for (i, s) in track.samples.enumerated() { out[start + i] += s }
    }
    return out
}

// Metallic FM hit: carrier + slightly-inharmonic modulator whose index decays
// fast (bell-like bite), over a sub octave. The voice of every capture.
func darkTone(freq: Double, duration: Double, attack: Double = 0.004,
              decay: Double, gain: Double, modRatio: Double = 2.01,
              modIndex: Double = 3.2, sub: Double = 0.5) -> [Double] {
    let n = Int(duration * sampleRate)
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        let e = envelope(t, attack: attack, decay: decay)
        let index = modIndex * exp(-t * 9)
        let mod = sin(2 * .pi * freq * modRatio * t) * index
        var s = sin(2 * .pi * freq * t + mod)
        s += sub * sin(2 * .pi * freq / 2 * t)
        return s * e * gain
    }
}

// Deterministic noise (fixed LCG so regeneration is byte-identical).
func makeNoise(seed: UInt64) -> () -> Double {
    var state = seed
    return {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53) * 2 - 1
    }
}

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// Capture ladder: A-phrygian rising from A2 — dark metallic pings, one step per
// capture. Low, dissonant intervals instead of the old pentatonic plinks.
let phrygian: [Double] = [110, 116.54, 130.81, 146.83, 155.56, 174.61, 196, 207.65]
for (i, freq) in phrygian.enumerated() {
    writeWav(darkTone(freq: freq, duration: 0.55, decay: 0.18, gain: 0.4), "plink\(i)")
}

// Perfect: a deep "BWOM" — sub swell with a tritone shimmer on top.
writeWav(mix([
    (0, darkTone(freq: 55, duration: 0.8, attack: 0.02, decay: 0.34, gain: 0.4,
                 modRatio: 1.0, modIndex: 0.0, sub: 0.0)),
    (0, darkTone(freq: 110, duration: 0.7, attack: 0.015, decay: 0.26, gain: 0.26)),
    (0.05, darkTone(freq: 155.56, duration: 0.6, decay: 0.22, gain: 0.2, modIndex: 4.2)),
]), "perfect")

// Power-up: alien shimmer — inharmonic partials with a fast tremolo.
func powerupSound() -> [Double] {
    let n = Int(0.55 * sampleRate)
    let partials: [(Double, Double)] = [(311, 0.34), (466, 0.24), (699, 0.18), (1047, 0.1)]
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        let e = envelope(t, attack: 0.01, decay: 0.2)
        let tremolo = 0.7 + 0.3 * sin(2 * .pi * 11 * t)
        var s = 0.0
        for (f, a) in partials { s += a * sin(2 * .pi * f * t + 0.8 * sin(2 * .pi * f * 2.02 * t)) }
        return s * tremolo * e * 0.42
    }
}
writeWav(powerupSound(), "powerup")

// Shield: a deep hull hum — beating pair swelling in, slow release.
func shieldSound() -> [Double] {
    let n = Int(0.9 * sampleRate)
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        let e = envelope(t, attack: 0.09, decay: 0.4)
        var s = sin(2 * .pi * 82.5 * t) + 0.9 * sin(2 * .pi * 84.2 * t)
        s += 0.35 * sin(2 * .pi * 165 * t)
        return s * e * 0.24
    }
}
writeWav(shieldSound(), "shield")

// Sector crossing: an ominous riser — swept drone into a low metallic hit.
func riserSound() -> [Double] {
    let n = Int(0.85 * sampleRate)
    var phase1 = 0.0, phase2 = 0.0
    let noise = makeNoise(seed: 777)
    var lp = 0.0
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        let sweep = 70 + 220 * (t / 0.85) * (t / 0.85)
        phase1 += 2 * .pi * sweep / sampleRate
        phase2 += 2 * .pi * (sweep * 1.011) / sampleRate
        lp += 0.05 * (noise() - lp)
        let swell = min(t / 0.6, 1.0)
        let tail = t > 0.7 ? exp(-(t - 0.7) / 0.1) : 1.0
        return ((sin(phase1) + sin(phase2)) * 0.24 + lp * 1.6 * swell) * swell * tail * 0.5
    }
}
writeWav(mix([
    (0, riserSound()),
    (0.72, darkTone(freq: 92.5, duration: 0.6, decay: 0.22, gain: 0.4, modIndex: 4.5)),
]), "levelup")

// Death: heavier — sub pitch-drop, gritty noise, soft-clipped for menace.
func deathSound() -> [Double] {
    let n = Int(0.95 * sampleRate)
    var phase = 0.0
    let noise = makeNoise(seed: 12345)
    var lp = 0.0
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        let freq = 95 * exp(-3.4 * t) + 28
        phase += 2 * .pi * freq / sampleRate
        lp += 0.07 * (noise() - lp)
        let e = envelope(t, attack: 0.002, decay: 0.3)
        let raw = sin(phase) * 1.1 + lp * 3.0 * exp(-6 * t)
        return tanh(raw * 1.6) * e * 0.52
    }
}
writeWav(deathSound(), "death")

// Launch: a dark thruster — low rumble under an airy swoosh.
func launchSound() -> [Double] {
    let n = Int(0.28 * sampleRate)
    let noise = makeNoise(seed: 999)
    var prev = 0.0
    var lp = 0.0
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        let e = envelope(t, attack: 0.04, decay: 0.09)
        let raw = noise()
        let hp = raw - prev
        prev = raw
        lp += 0.04 * (raw - lp)
        return (hp * 0.16 + lp * 1.4 * exp(-5 * t) + 0.2 * sin(2 * .pi * 78 * t) * e) * e
    }
}
writeWav(launchSound(), "launch")

// Bouncer: a metallic clang — high-ratio FM, fast decay.
writeWav(darkTone(freq: 196, duration: 0.3, decay: 0.1, gain: 0.4,
                  modRatio: 3.76, modIndex: 6.5, sub: 0.3), "bounce")

// Streak: an eerie beating riser — the hot-combo PERFECT voice.
func streakSound() -> [Double] {
    let n = Int(0.45 * sampleRate)
    var phase1 = 0.0, phase2 = 0.0
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        let sweep = 220 + 340 * (t / 0.45)
        phase1 += 2 * .pi * sweep / sampleRate
        phase2 += 2 * .pi * (sweep * 1.007 + 1.8) / sampleRate
        let e = envelope(t, attack: 0.012, decay: 0.16)
        return (sin(phase1) + sin(phase2) + 0.3 * sin(phase1 * 2)) * e * 0.24
    }
}
writeWav(streakSound(), "streak")

// Ambient pad: 12 s seamless loop of slow dread — a minor-second beat over the
// root, a tritone drifting through, everything at k/12 Hz so the loop is exact.
func padSound() -> [Double] {
    let duration = 12.0
    let n = Int(duration * sampleRate)
    // 55 = 660/12 · 58.33 = 700/12 (minor 2nd beat) · 77.75 = 933/12 (tritone)
    let voices: [(freq: Double, amp: Double)] = [
        (55, 0.5), (55 + 1.0 / 12.0, 0.3),
        (58.0 + 4.0 / 12.0, 0.3),
        (77.75, 0.26), (77.75 + 1.0 / 12.0, 0.16),
        (110, 0.22), (165, 0.1),
    ]
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        var s = 0.0
        for (j, voice) in voices.enumerated() {
            let lfo = 0.7 + 0.3 * sin(2 * .pi * (Double(j % 4 + 1) / 12.0) * t + Double(j) * 1.3)
            s += voice.amp * lfo * sin(2 * .pi * voice.freq * t)
        }
        // A slow sub pulse (2 cycles over the loop) breathing underneath.
        s += 0.12 * sin(2 * .pi * (2.0 / 12.0) * t) * sin(2 * .pi * 41.25 * t)
        return s * 0.14
    }
}
writeWav(padSound(), "ambient")
