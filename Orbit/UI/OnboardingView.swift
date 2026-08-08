import SwiftUI

// First-launch gate: pick a name (max 50 chars) before playing. One profile per device.
struct OnboardingView: View {
    let initialAvatar: Int
    let onDone: (Profile) -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                AvatarView(index: initialAvatar, size: 96)
                    .allowsHitTesting(false)
                Text("WHAT'S YOUR NAME?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .allowsHitTesting(false)
                Text("Shown on the leaderboard · one profile per device")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textDim)
                    .allowsHitTesting(false)
                TextField("", text: $name, prompt: Text("Your name").foregroundColor(Theme.textDim))
                    .focused($focused)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 40)
                    .onChange(of: name) { value in
                        if value.count > 50 { name = String(value.prefix(50)) }
                    }
                Button {
                    onDone(Profile(name: trimmed, avatar: initialAvatar))
                } label: {
                    Text("START")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 60)
                        .background(Theme.gold, in: Capsule())
                }
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.4 : 1)
                Spacer()
                Spacer()
            }
        }
        .onAppear { focused = true }
    }
}
