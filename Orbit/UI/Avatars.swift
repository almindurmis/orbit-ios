import SwiftUI

// 20 distinct avatars: 4 gradients x 5 symbols, addressed deterministically by index.
enum Avatars {
    static let count = 20

    private static let gradients: [[Color]] = [
        [Color(red: 0.35, green: 0.85, blue: 1.0), Color(red: 0.20, green: 0.40, blue: 0.90)],
        [Color(red: 1.00, green: 0.55, blue: 0.75), Color(red: 0.70, green: 0.20, blue: 0.70)],
        [Color(red: 1.00, green: 0.80, blue: 0.40), Color(red: 0.95, green: 0.45, blue: 0.20)],
        [Color(red: 0.45, green: 0.95, blue: 0.70), Color(red: 0.10, green: 0.55, blue: 0.50)],
    ]
    private static let symbols = ["moon.stars.fill", "sparkles", "star.fill", "sun.max.fill", "circle.dashed"]

    static func gradient(for index: Int) -> [Color] { gradients[index % gradients.count] }
    static func symbol(for index: Int) -> String { symbols[(index / gradients.count) % symbols.count] }
}

struct AvatarView: View {
    let index: Int
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: Avatars.gradient(for: index),
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: Avatars.symbol(for: index))
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
