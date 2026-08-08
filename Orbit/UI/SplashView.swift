import SwiftUI

// Shown for 1s over the game at cold start, matching the static launch screen color.
// The white dot orbits the ring just like in gameplay.
struct SplashView: View {
    @State private var spinning = false

    private let cyan = Color(red: 0.32, green: 0.9, blue: 1.0)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(cyan, lineWidth: 5)
                        .frame(width: 110, height: 110)
                        .shadow(color: cyan.opacity(0.8), radius: 12)
                    Circle()
                        .fill(cyan)
                        .frame(width: 26, height: 26)
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .white, radius: 8)
                        .offset(y: -55)
                        .rotationEffect(.degrees(spinning ? 360 : 0))
                }
                Text("O R B I T")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                spinning = true
            }
        }
    }
}
