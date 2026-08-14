import SwiftUI

// The Run Lab: seed codes turn a run into a shareable challenge — the same
// code produces the same planets, obstacles and power-ups for everyone.
// Anyone can PLAY a code; generating fresh ones is a Premium perk.
struct RunLabView: View {
    let onPlay: (UInt64) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var premium = Premium.shared
    @State private var code = ""
    @State private var generated = ""
    @State private var showPaywall = false

    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func seed(for code: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in code.uppercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    private var cleanCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var body: some View {
        ZStack {
            GalaxyBackground()
            VStack(spacing: 22) {
                Text("RUN LAB")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 24)
                Text("A code is a whole world — same planets,\nsame walls, same gates for everyone who flies it.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center)

                VStack(spacing: 14) {
                    TextField("", text: $code,
                              prompt: Text("ENTER CODE").foregroundColor(Theme.textDim))
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    Button {
                        onPlay(Self.seed(for: cleanCode))
                        dismiss()
                    } label: {
                        Text("FLY THIS CODE")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Theme.gold, in: Capsule())
                    }
                    .disabled(cleanCode.count < 3)
                    .opacity(cleanCode.count < 3 ? 0.4 : 1)
                }
                .padding(20)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    Text(premium.isActive ? "CREATE A CHALLENGE" : "CREATE A CHALLENGE ⭐")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.gold)
                    if !generated.isEmpty {
                        Text(generated)
                            .font(.system(size: 30, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white)
                        ShareLink(item: "Fly my Orbit run — code \(generated). Same world, best score wins. 🚀") {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.gold)
                        }
                        Button {
                            onPlay(Self.seed(for: generated))
                            dismiss()
                        } label: {
                            Text("FLY IT")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 44)
                                .background(Theme.gold, in: Capsule())
                        }
                    }
                    Button {
                        if premium.isActive {
                            generated = String((0..<6).map { _ in Self.alphabet.randomElement()! })
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Text(generated.isEmpty ? "GENERATE CODE" : "NEW CODE")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.gold)
                            .padding(.vertical, 11)
                            .padding(.horizontal, 34)
                            .overlay(Capsule().stroke(Theme.gold.opacity(0.7), lineWidth: 1.5))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .sheet(isPresented: $showPaywall) { PremiumView() }
    }
}
