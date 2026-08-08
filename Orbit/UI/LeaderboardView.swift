import SwiftUI

// Custom segmented control: readable unselected labels on the dark backdrop.
struct PeriodPicker: View {
    @Binding var selection: LeaderboardPeriod

    var body: some View {
        HStack(spacing: 6) {
            ForEach(LeaderboardPeriod.allCases) { period in
                Button {
                    selection = period
                } label: {
                    Text(period.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selection == period ? .black : .white.opacity(0.78))
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(selection == period ? Theme.gold : Color.white.opacity(0.10),
                                    in: Capsule())
                }
            }
        }
    }
}

struct LeaderboardView: View {
    @State private var period: LeaderboardPeriod = .weekly
    @State private var entries: [LeaderboardEntry] = []
    @State private var loading = false
    @State private var failed = false

    var body: some View {
        ZStack {
            GalaxyBackground()
            VStack(spacing: 16) {
                Text("LEADERBOARD")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 24)
                PeriodPicker(selection: $period)
                    .padding(.horizontal, 24)
                content
            }
        }
        .task(id: period) { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        if !Backend.isConfigured {
            message("Leaderboard is offline.\nFirebase isn't configured in this build yet.")
        } else if loading {
            Spacer()
            ProgressView().tint(.white)
            Spacer()
        } else if failed {
            message("Couldn't load scores.\nCheck your connection and try again.")
        } else if entries.isEmpty {
            message("No scores yet.\nBe the first on the board!")
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { rank, entry in
                        row(rank: rank + 1, entry: entry)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private func row(rank: Int, entry: LeaderboardEntry) -> some View {
        let isMe = entry.id == DeviceID.id
        return HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .foregroundStyle(rank <= 3 ? Theme.gold : Theme.textDim)
                .frame(width: 34)
            AvatarView(index: entry.avatar, size: 38)
            Text(entry.name)
                .font(.system(size: 16, weight: isMe ? .bold : .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text("\(entry.score)")
                .font(.system(size: 18, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(isMe ? Theme.gold.opacity(0.18) : Color.white.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func message(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func reload() async {
        loading = true
        failed = false
        do {
            entries = try await Backend.leaderboard(period)
        } catch {
            failed = true
        }
        loading = false
    }
}
