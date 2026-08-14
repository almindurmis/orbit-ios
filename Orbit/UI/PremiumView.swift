import SwiftUI
import StoreKit

// The Orbit Premium paywall. Products come from App Store Connect; when they
// haven't loaded (offline, not yet configured) the sheet still explains the
// bundle and offers restore.
struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var premium = Premium.shared
    @State private var purchasing = false

    private let benefits: [(String, String)] = [
        ("nosign", "No interstitial ads — ever"),
        ("arrow.counterclockwise.circle", "One revive per classic run"),
        ("moon.stars", "Zen Drift — deathless endless flight"),
        ("flask", "Run Lab — create & share seed codes"),
        ("chart.bar", "Full pilot stats history"),
        ("sparkles", "PRISM & EMBERS animated trails"),
        ("star.circle", "Gold star on the leaderboard"),
        ("bolt", "Double mission XP"),
    ]

    private var staged: Bool {
        ProcessInfo.processInfo.arguments.contains("-fakestore")
    }

    private func stagedButton(_ title: String, _ price: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Text(price)
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.75)
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.gold, in: Capsule())
        .padding(.horizontal, 40)
    }

    var body: some View {
        ZStack {
            GalaxyBackground()
            VStack(spacing: 18) {
                Text("ORBIT PREMIUM")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 28)

                if premium.isActive {
                    Label("ACTIVE", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.gold)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(benefits, id: \.1) { icon, text in
                        HStack(spacing: 12) {
                            Image(systemName: icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.gold)
                                .frame(width: 24)
                            Text(text)
                                .font(.system(size: 14.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 24)

                if !premium.isActive {
                    if staged {
                        // Screenshot staging (-fakestore): the exact purchase buttons with
                        // the store's real US prices, for the review-information capture.
                        stagedButton("ORBIT PREMIUM MONTHLY", "$4.99/month")
                        stagedButton("ORBIT PREMIUM YEARLY", "$34.99/year")
                    } else if premium.products.isEmpty {
                        Text("Subscriptions are loading…\nCheck your connection if this persists.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textDim)
                            .multilineTextAlignment(.center)
                    } else {
                        ForEach(premium.products, id: \.id) { product in
                            Button {
                                purchasing = true
                                Task {
                                    await premium.purchase(product)
                                    purchasing = false
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(product.displayName.isEmpty ? "SUBSCRIBE" : product.displayName.uppercased())
                                        .font(.system(size: 15, weight: .bold))
                                    Text(product.displayPrice)
                                        .font(.system(size: 12, weight: .semibold))
                                        .opacity(0.75)
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.gold, in: Capsule())
                            }
                            .disabled(purchasing)
                            .padding(.horizontal, 40)
                        }
                    }
                }

                Button("Restore Purchases") {
                    Task { await premium.restore() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

                Spacer()

                HStack(spacing: 16) {
                    Link("Privacy", destination: URL(string: "https://almindurmis.github.io/orbit-ios/privacy.html")!)
                    Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.textDim)

                Button("CLOSE") { dismiss() }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 26)
            }
        }
    }
}
