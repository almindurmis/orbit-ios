// Generates every sound in Orbit/Sounds as 16-bit mono WAVs.
// Run from the repo root: swift Tools/make-sounds.swift
// The ambient pad only uses frequencies that fit whole cycles into its 12s
// length, so it loops seamlessly.
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

// A note = fundamental + soft second harmonic with an exponential decay.
func note(freq: Double, duration: Double, attack: Double = 0.005,
          decay: Double, gain: Double, detune: Double = 0) -> [Double] {
    let n = Int(duration * sampleRate)
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        let e = envelope(t, attack: attack, decay: decay)
        var s = sin(2 * .pi * freq * t) + 0.28 * sin(2 * .pi * freq * 2 * t)
        if detune > 0 { s += 0.6 * sin(2 * .pi * (freq + detune) * t) }
        return s * e * gain
    }
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

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// Capture plinks: A-major pentatonic ladder, one step per capture.
let pentatonic: [Double] = [440, 494, 554, 659, 740, 880, 988, 1109]
for (i, freq) in pentatonic.enumerated() {
    writeWav(note(freq: freq, duration: 0.5, decay: 0.13, gain: 0.4), "plink\(i)")
}

// Perfect: two bright staggered notes.
writeWav(mix([
    (0, note(freq: 880, duration: 0.5, decay: 0.18, gain: 0.34)),
    (0.07, note(freq: 1318.5, duration: 0.5, decay: 0.22, gain: 0.3)),
]), "perfect")

// Power-up: quick sparkle arpeggio.
writeWav(mix([
    (0, note(freq: 660, duration: 0.4, decay: 0.12, gain: 0.3)),
    (0.06, note(freq: 880, duration: 0.4, decay: 0.13, gain: 0.28)),
    (0.12, note(freq: 1108, duration: 0.45, decay: 0.16, gain: 0.28)),
]), "powerup")

// Shield save: low warble rising to a soft high note.
writeWav(mix([
    (0, note(freq: 330, duration: 0.5, decay: 0.2, gain: 0.3, detune: 3)),
    (0.12, note(freq: 660, duration: 0.5, decay: 0.25, gain: 0.26)),
]), "shield")

// Level up: rising four-note arpeggio.
writeWav(mix([
    (0.00, note(freq: 523.25, duration: 0.5, decay: 0.16, gain: 0.3)),
    (0.09, note(freq: 659.25, duration: 0.5, decay: 0.16, gain: 0.3)),
    (0.18, note(freq: 783.99, duration: 0.5, decay: 0.18, gain: 0.3)),
    (0.27, note(freq: 1046.5, duration: 0.7, decay: 0.26, gain: 0.32)),
]), "levelup")

// Bouncer ricochet: springy pitch-rising chirp with a light vibrato.
func bounceSound() -> [Double] {
    let n = Int(0.22 * sampleRate)
    var phase = 0.0
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        let freq = 240 + 2400 * t + 18 * sin(2 * .pi * 38 * t)
        phase += 2 * .pi * freq / sampleRate
        let e = envelope(t, attack: 0.004, decay: 0.08)
        return (sin(phase) + 0.22 * sin(2 * phase)) * e * 0.34
    }
}
writeWav(bounceSound(), "bounce")

// Streak: a PERFECT while the combo is hot — two fast bright notes, up a fifth.
writeWav(mix([
    (0, note(freq: 988, duration: 0.35, decay: 0.12, gain: 0.3)),
    (0.05, note(freq: 1480, duration: 0.45, decay: 0.2, gain: 0.3)),
]), "streak")

// Death: pitch-dropping thump plus a low-passed noise burst.
func deathSound() -> [Double] {
    let n = Int(0.7 * sampleRate)
    var phase = 0.0
    var state: UInt64 = 12345
    func noise() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53) * 2 - 1
    }
    var lp = 0.0
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        let freq = 130 * exp(-4 * t) + 45
        phase += 2 * .pi * freq / sampleRate
        lp += 0.08 * (noise() - lp)
        let e = envelope(t, attack: 0.002, decay: 0.22)
        return (sin(phase) * 0.8 + lp * 2.2 * exp(-8 * t)) * e * 0.5
    }
}
writeWav(deathSound(), "death")

// Launch: short airy swoosh (differentiated noise so it reads as high, not hissy).
func launchSound() -> [Double] {
    let n = Int(0.22 * sampleRate)
    var state: UInt64 = 999
    func noise() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53) * 2 - 1
    }
    var prev = 0.0
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        let e = envelope(t, attack: 0.04, decay: 0.07)
        let raw = noise()
        let hp = raw - prev
        prev = raw
        return hp * e * 0.22
    }
}
writeWav(launchSound(), "launch")

// Ambient pad: 12s seamless loop. Every frequency (and LFO rate) is k/12 Hz,
// so the waveform is exactly periodic over the file length.
func padSound() -> [Double] {
    let duration = 12.0
    let n = Int(duration * sampleRate)
    let voices: [(freq: Double, amp: Double)] = [
        (55, 0.5), (55 + 1.0 / 12.0, 0.35),
        (82.5, 0.35), (82.5 + 1.0 / 12.0, 0.24),
        (110, 0.3), (110 + 1.0 / 12.0, 0.2),
        (165, 0.18), (165 + 1.0 / 12.0, 0.12),
    ]
    return (0..<n).map { i in
        let t = Double(i) / sampleRate
        var s = 0.0
        for (j, voice) in voices.enumerated() {
            let lfo = 0.75 + 0.25 * sin(2 * .pi * (Double(j % 4 + 1) / 12.0) * t + Double(j))
            s += voice.amp * lfo * sin(2 * .pi * voice.freq * t)
        }
        return s * 0.15
    }
}
writeWav(padSound(), "ambient")
