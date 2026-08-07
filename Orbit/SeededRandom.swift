import CoreGraphics

// splitmix64 — deterministic across devices so a daily seed yields the same run for everyone.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func cgFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let unit = CGFloat(next() >> 11) * (1.0 / CGFloat(UInt64(1) << 53))
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}
