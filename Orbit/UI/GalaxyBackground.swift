import SwiftUI

// Shared backdrop for the Leaderboard and Profile sheets: a lighter galactic
// gradient with nebula glows and a deterministic star field, so the screen
// reads as a surface instead of dissolving into black at the edges.
struct GalaxyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.07, green: 0.08, blue: 0.20),
                Color(red: 0.11, green: 0.08, blue: 0.26),
                Color(red: 0.04, green: 0.05, blue: 0.13),
            ], startPoint: .top, endPoint: .bottom)

            RadialGradient(colors: [Color(red: 0.45, green: 0.30, blue: 0.90).opacity(0.28), .clear],
                           center: UnitPoint(x: 0.85, y: 0.12), startRadius: 0, endRadius: 340)
            RadialGradient(colors: [Color(red: 0.20, green: 0.70, blue: 0.90).opacity(0.20), .clear],
                           center: UnitPoint(x: 0.10, y: 0.78), startRadius: 0, endRadius: 320)

            Canvas { context, size in
                var seed: UInt64 = 7
                func rnd() -> Double {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return Double(seed >> 33) / Double(UInt32.max)
                }
                let tints: [Color] = [.white, .white,
                                      Color(red: 0.72, green: 0.85, blue: 1.0),
                                      Color(red: 1.0, green: 0.9, blue: 0.78)]
                for _ in 0..<140 {
                    let x = rnd() * size.width
                    let y = rnd() * size.height
                    let r = 0.4 + rnd() * 1.3
                    let alpha = 0.15 + rnd() * 0.55
                    let tint = tints[Int(rnd() * 3.999)]
                    context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                 with: .color(tint.opacity(alpha)))
                }
            }
        }
        .ignoresSafeArea()
    }
}
