import SwiftUI

struct ProfileView: View {
    let profile: Profile
    let onSave: (Profile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var avatar: Int

    init(profile: Profile, onSave: @escaping (Profile) -> Void) {
        self.profile = profile
        self.onSave = onSave
        _name = State(initialValue: profile.name)
        _avatar = State(initialValue: profile.avatar)
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 5)

    var body: some View {
        ZStack {
            GalaxyBackground()
            VStack(spacing: 22) {
                Text("PROFILE")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 24)
                AvatarView(index: avatar, size: 88)
                TextField("", text: $name, prompt: Text("Your name").foregroundColor(Theme.textDim))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 40)
                    .onChange(of: name) { value in
                        if value.count > 50 { name = String(value.prefix(50)) }
                    }
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(0..<Avatars.count, id: \.self) { index in
                        Button {
                            avatar = index
                        } label: {
                            AvatarView(index: index, size: 52)
                                .overlay(
                                    Circle().stroke(index == avatar ? Theme.gold : .clear, lineWidth: 3)
                                )
                        }
                    }
                }
                .padding(.horizontal, 28)
                Button {
                    onSave(Profile(name: trimmed, avatar: avatar))
                    dismiss()
                } label: {
                    Text("SAVE")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 60)
                        .background(Theme.gold, in: Capsule())
                }
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.4 : 1)
                Spacer()
            }
        }
    }
}
