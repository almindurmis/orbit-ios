import SwiftUI

// Shown for 1.5s over the game at cold start, matching the static launch screen color.
struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(Color(red: 0.32, green: 0.9, blue: 1.0), lineWidth: 5)
                        .frame(width: 110, height: 110)
                        .shadow(color: Color(red: 0.32, green: 0.9, blue: 1.0).opacity(0.8), radius: 12)
                    Circle()
                        .fill(Color(red: 0.32, green: 0.9, blue: 1.0))
                        .frame(width: 26, height: 26)
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .white, radius: 8)
                        .offset(x: 55 * cos(.pi / 4), y: -55 * sin(.pi / 4))
                }
                Text("O R B I T")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
